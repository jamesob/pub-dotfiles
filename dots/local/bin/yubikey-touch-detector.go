// yubikey-touch-detector, inlined into a single standard-library-only Go file.
//
// This is a faithful port of github.com/maximbaz/yubikey-touch-detector
// (ISC License, Copyright (c) 2017-2021 Maxim Baz) with every third-party
// dependency replaced by the Go standard library so the program is one file
// you can run directly:
//
//     go run yubikey-touch-detector.go            # detect touches + show the Sway bar
//     go run yubikey-touch-detector.go -no-bar    # detection only (no swaynag bar)
//     go run yubikey-touch-detector.go -v -stdout # debug log on stderr + event codes
//
// Or build a static binary:  go build -o ytd yubikey-touch-detector.go
//
// Substitutions vs. upstream:
//   rjeczalik/notify  -> raw inotify via syscall
//   vtolstov/go-ioctl -> HIDIOC* request numbers computed inline + SYS_IOCTL
//   deckarep/golang-set -> map[string]struct{}
//   sirupsen/logrus   -> stdlib log
//   coreos/go-systemd -> dropped (no socket activation; we create our own socket)
//   proglottis/gpgme  -> Assuan "LEARN" spoken directly over the gpg-agent
//                        unix socket (same busy-check signal, no cgo)
//
// Added on top of upstream: a built-in swaynag "Touch your YubiKey" bar that
// appears while any touch is pending and disappears once it resolves, so this
// one file replaces both the detector and the external bar script.
//
// Linux only (inotify, hidraw, SYS_IOCTL). Tested to build on amd64/arm64.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

// ---------------------------------------------------------------------------
// Messages (wire-compatible with upstream: fixed 5-char codes, no delimiter)
// ---------------------------------------------------------------------------

type Message string

const (
	GPG_ON   Message = "GPG_1"
	GPG_OFF  Message = "GPG_0"
	U2F_ON   Message = "U2F_1"
	U2F_OFF  Message = "U2F_0"
	HMAC_ON  Message = "MAC_1"
	HMAC_OFF Message = "MAC_0"
)

// ---------------------------------------------------------------------------
// Notifier hub: fans every event out to stdout (optional) and all connected
// unix-socket clients. Replaces upstream's sync.Map-of-channels + notifiers.
// ---------------------------------------------------------------------------

type Hub struct {
	mu      sync.Mutex
	clients map[net.Conn]struct{}
	subs    []chan Message
	stdout  bool
}

func NewHub(stdout bool) *Hub {
	return &Hub{clients: make(map[net.Conn]struct{}), stdout: stdout}
}

// Subscribe returns a channel receiving every event in-process. Used by the
// built-in Sway bar. Call before events start flowing.
func (h *Hub) Subscribe() <-chan Message {
	ch := make(chan Message, 64)
	h.mu.Lock()
	h.subs = append(h.subs, ch)
	h.mu.Unlock()
	return ch
}

func (h *Hub) Send(m Message) {
	log.Printf("[event] %s", m)
	if h.stdout {
		fmt.Println(string(m))
	}
	h.mu.Lock()
	for c := range h.clients {
		_ = c.SetWriteDeadline(time.Now().Add(time.Second))
		if _, err := c.Write([]byte(m)); err != nil {
			c.Close()
			delete(h.clients, c)
		}
	}
	subs := h.subs
	h.mu.Unlock()
	// Deliver to in-process subscribers outside the lock. Buffered + a fast
	// consumer make this effectively non-blocking and lossless.
	for _, ch := range subs {
		ch <- m
	}
}

func (h *Hub) addClient(c net.Conn) {
	h.mu.Lock()
	h.clients[c] = struct{}{}
	h.mu.Unlock()
}

func (h *Hub) dropClient(c net.Conn) {
	h.mu.Lock()
	delete(h.clients, c)
	h.mu.Unlock()
	c.Close()
}

// ---------------------------------------------------------------------------
// Cleanup registry: runs on SIGINT/SIGTERM. Critical for the SSH proxy, which
// moves the user's agent socket aside and must put it back on exit.
// ---------------------------------------------------------------------------

var (
	cleanupMu    sync.Mutex
	cleanupFuncs []func()
)

func onExit(f func()) {
	cleanupMu.Lock()
	cleanupFuncs = append(cleanupFuncs, f)
	cleanupMu.Unlock()
}

func runCleanup() {
	cleanupMu.Lock()
	fns := cleanupFuncs
	cleanupMu.Unlock()
	// LIFO so the SSH socket is restored in reverse order of setup.
	for i := len(fns) - 1; i >= 0; i-- {
		fns[i]()
	}
}

// ---------------------------------------------------------------------------
// Minimal inotify helpers (replaces rjeczalik/notify)
// ---------------------------------------------------------------------------

type inEvent struct {
	Name string
	Mask uint32
	Wd   int32
}

const sizeofInotifyEvent = uint32(syscall.SizeofInotifyEvent) // 16

// readLoop pumps a raw inotify fd into a channel until the fd errors/closes.
func readLoop(fd int, ch chan<- inEvent) {
	buf := make([]byte, 64*1024)
	for {
		n, err := syscall.Read(fd, buf)
		if err != nil {
			if err == syscall.EINTR {
				continue
			}
			close(ch)
			return
		}
		var off uint32
		for off+sizeofInotifyEvent <= uint32(n) {
			raw := (*syscall.InotifyEvent)(unsafe.Pointer(&buf[off]))
			nameLen := raw.Len
			var name string
			if nameLen > 0 {
				start := off + sizeofInotifyEvent
				b := buf[start : start+nameLen]
				name = strings.TrimRight(string(b), "\x00")
			}
			ch <- inEvent{Name: name, Mask: raw.Mask, Wd: raw.Wd}
			off += sizeofInotifyEvent + nameLen
		}
	}
}

// watchDir watches a single directory for the given mask.
func watchDir(dir string, mask uint32) (<-chan inEvent, error) {
	fd, err := syscall.InotifyInit1(syscall.IN_CLOEXEC)
	if err != nil {
		return nil, err
	}
	if _, err := syscall.InotifyAddWatch(fd, dir, mask); err != nil {
		syscall.Close(fd)
		return nil, err
	}
	ch := make(chan inEvent, 64)
	go readLoop(fd, ch)
	return ch, nil
}

// ---------------------------------------------------------------------------
// hidraw ioctls (replaces vtolstov/go-ioctl)
// ---------------------------------------------------------------------------

// _IOC encoding from <asm-generic/ioctl.h>
const (
	iocNRBITS    = 8
	iocTYPEBITS  = 8
	iocSIZEBITS  = 14
	iocNRSHIFT   = 0
	iocTYPESHIFT = iocNRSHIFT + iocNRBITS
	iocSIZESHIFT = iocTYPESHIFT + iocTYPEBITS
	iocDIRSHIFT  = iocSIZESHIFT + iocSIZEBITS
	iocREAD      = 2
)

func ior(typ, nr, size uintptr) uintptr {
	return (iocREAD << iocDIRSHIFT) | (typ << iocTYPESHIFT) | (nr << iocNRSHIFT) | (size << iocSIZESHIFT)
}

// https://github.com/torvalds/linux/blob/master/include/uapi/linux/hidraw.h
type hidrawDescriptor struct {
	Size  uint32
	Value [4096]uint8
}

var (
	hidiocgrdescsize = ior('H', 1, 4)
	hidiocgrdesc     = ior('H', 2, unsafe.Sizeof(hidrawDescriptor{}))
)

func ioctl(fd, request, arg uintptr) error {
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, fd, request, arg)
	if errno != 0 {
		return errno
	}
	return nil
}

// FIDO HID constants (from u2f_hid.h / CTAP2 spec, same values as upstream)
const (
	typeInit         = 0x80
	ctaphidMsg       = typeInit | 0x03
	ctaphidKeepalive = typeInit | 0x3b
	fidoUsagePage    = 0xf1d0
	fidoUsageCtaphid = 0x01
	statusUpneeded   = 0x02

	u2fSWConditionsNotSatisfied = 0x6985

	hidItemTypeGlobal        = 1
	hidItemTypeLocal         = 2
	hidGlobalItemTagUsagePg  = 0
	hidLocalItemTagUsage     = 0
)

// ---------------------------------------------------------------------------
// U2F / FIDO2 detector (port of detector/u2f.go)
// ---------------------------------------------------------------------------

func watchU2F(hub *Hub) {
	check := func(devicePath string) {
		if isFidoU2FDevice(devicePath) {
			go runU2FWatcher(devicePath, hub)
		}
	}

	events, err := watchDir("/dev", syscall.IN_CREATE)
	if err != nil {
		log.Printf("U2F: cannot watch /dev: %v", err)
		return
	}

	if devices, err := os.ReadDir("/dev"); err == nil {
		for _, d := range devices {
			check(path.Join("/dev", d.Name()))
		}
	} else {
		log.Printf("U2F: cannot list /dev: %v", err)
	}

	for ev := range events {
		time.Sleep(1 * time.Second) // let the device initialize
		check(path.Join("/dev", ev.Name))
	}
}

func isFidoU2FDevice(devicePath string) bool {
	if !strings.HasPrefix(devicePath, "/dev/hidraw") {
		return false
	}
	device, err := os.Open(devicePath)
	if err != nil {
		return false
	}
	defer device.Close()

	var size uint32
	if err := ioctl(device.Fd(), hidiocgrdescsize, uintptr(unsafe.Pointer(&size))); err != nil {
		return false
	}
	data := hidrawDescriptor{Size: size}
	if err := ioctl(device.Fd(), hidiocgrdesc, uintptr(unsafe.Pointer(&data))); err != nil {
		return false
	}

	isFido, hasU2F := false, false
	for i := uint32(0); i+2 < size && i+2 < uint32(len(data.Value)); {
		prefix := data.Value[i]
		tag := (prefix & 0b11110000) >> 4
		typ := (prefix & 0b00001100) >> 2
		sz := prefix & 0b00000011

		val1b := data.Value[i+1]
		val2b := int(data.Value[i+1]) | (int(data.Value[i+2]) << 8)

		if typ == hidItemTypeGlobal && tag == hidGlobalItemTagUsagePg && val2b == fidoUsagePage {
			isFido = true
		} else if typ == hidItemTypeLocal && tag == hidLocalItemTagUsage && int(val1b) == fidoUsageCtaphid {
			hasU2F = true
		}
		if isFido && hasU2F {
			return true
		}
		i += uint32(sz) + 1
	}
	return false
}

func runU2FWatcher(devicePath string, hub *Hub) {
	device, err := os.Open(devicePath)
	if err != nil {
		log.Printf("U2F: cannot open %v: %v", devicePath, err)
		return
	}
	defer device.Close()

	payload := make([]byte, 64)
	last := U2F_OFF
	var offTimer *time.Timer

	for {
		if _, err := device.Read(payload); err != nil {
			if offTimer != nil {
				offTimer.Stop()
			}
			if last != U2F_OFF {
				hub.Send(U2F_OFF)
			}
			return
		}

		val1b := payload[7]
		val2b := (int(payload[7]) << 8) | int(payload[8])
		isU2F := payload[4] == ctaphidMsg && val2b == u2fSWConditionsNotSatisfied
		isFIDO2 := payload[4] == ctaphidKeepalive && val1b == statusUpneeded

		if offTimer != nil {
			offTimer.Stop()
		}

		offDuration := 200 * time.Millisecond
		if isU2F || isFIDO2 {
			if last != U2F_ON {
				hub.Send(U2F_ON)
				last = U2F_ON
			}
			offDuration = 2 * time.Second
		}

		offTimer = time.AfterFunc(offDuration, func() {
			if last != U2F_OFF {
				hub.Send(U2F_OFF)
				last = U2F_OFF
			}
		})
	}
}

// ---------------------------------------------------------------------------
// HMAC detector (port of detector/hmac.go) - YubiKey hidraw appear/disappear
// ---------------------------------------------------------------------------

func watchHMAC(hub *Hub) {
	events, err := watchDir("/dev", syscall.IN_CREATE|syscall.IN_DELETE)
	if err != nil {
		log.Printf("HMAC: cannot watch /dev: %v", err)
		return
	}

	devices := make(map[string]struct{})
	if entries, err := os.ReadDir("/dev"); err == nil {
		for _, d := range entries {
			p := path.Join("/dev", d.Name())
			if isYubikeyHidrawDevice(p) {
				devices[p] = struct{}{}
			}
		}
	}

	last := HMAC_OFF
	var onRemoveTimer *time.Timer

	for ev := range events {
		p := path.Join("/dev", ev.Name)
		switch {
		case ev.Mask&syscall.IN_CREATE != 0:
			if onRemoveTimer != nil {
				onRemoveTimer.Stop()
			}
			time.Sleep(1 * time.Second)
			if isYubikeyHidrawDevice(p) {
				devices[p] = struct{}{}
				if last != HMAC_OFF {
					hub.Send(HMAC_OFF)
				}
				last = HMAC_OFF
			}
		case ev.Mask&syscall.IN_DELETE != 0:
			if _, ok := devices[p]; ok {
				if onRemoveTimer != nil {
					onRemoveTimer.Stop()
				}
				delete(devices, p)
				onRemoveTimer = time.AfterFunc(1*time.Second, func() {
					next := HMAC_OFF
					if len(devices) > 0 {
						next = HMAC_ON
					}
					if last != next {
						hub.Send(next)
					}
					last = next
				})
			}
		}
	}
}

func isYubikeyHidrawDevice(devicePath string) bool {
	if !strings.HasPrefix(devicePath, "/dev/hidraw") {
		return false
	}
	uevent := fmt.Sprintf("/sys/class/hidraw/%v/device/uevent", path.Base(devicePath))
	info, err := os.ReadFile(uevent)
	if err != nil {
		return false
	}
	return strings.Contains(strings.ToLower(string(info)), "yubikey")
}

// ---------------------------------------------------------------------------
// GPG detection (port of detector/gpg.go + detector/ssh.go, gpgme replaced
// by raw Assuan over the gpg-agent socket)
// ---------------------------------------------------------------------------

func gpgHomedir() string {
	if out, err := exec.Command("gpgconf", "--list-dirs", "homedir").Output(); err == nil {
		if s := strings.TrimSpace(string(out)); s != "" {
			return s
		}
	}
	if h := os.Getenv("GNUPGHOME"); h != "" {
		return h
	}
	if h := os.Getenv("HOME"); h != "" {
		return path.Join(h, ".gnupg")
	}
	return ""
}

func gpgAgentSocket() string {
	if out, err := exec.Command("gpgconf", "--list-dirs", "agent-socket").Output(); err == nil {
		if s := strings.TrimSpace(string(out)); s != "" {
			return s
		}
	}
	if rd := os.Getenv("XDG_RUNTIME_DIR"); rd != "" {
		return path.Join(rd, "gnupg/S.gpg-agent")
	}
	return ""
}

// findShadowedPrivateKeys returns the stub key files that point at a smartcard.
func findShadowedPrivateKeys(dir string) []string {
	var result []string
	_ = filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return nil
		}
		if strings.Contains(string(data), "shadowed-private-key") {
			result = append(result, p)
		}
		return nil
	})
	return result
}

func initGPGDetectors(hub *Hub) {
	homedir := gpgHomedir()
	if homedir == "" {
		log.Print("GPG: cannot determine homedir, disabling GPG/SSH watchers")
		return
	}
	keysDir := path.Join(homedir, "private-keys-v1.d")
	if _, err := os.Stat(keysDir); err != nil {
		log.Printf("GPG: '%s' missing, disabling GPG/SSH watchers", keysDir)
		return
	}
	files := findShadowedPrivateKeys(keysDir)
	if len(files) == 0 {
		log.Print("GPG: no smartcard-shadowed keys found, disabling GPG/SSH watchers")
		return
	}

	agentSocket := gpgAgentSocket()
	if agentSocket == "" {
		log.Print("GPG: cannot locate gpg-agent socket, disabling GPG/SSH watchers")
		return
	}

	requestGPGCheck := make(chan struct{}, 1)
	go checkGPGOnRequest(requestGPGCheck, agentSocket, hub)
	go watchGPG(files, requestGPGCheck)
	go watchSSH(requestGPGCheck)
}

// trigger does a non-blocking send on the check channel.
func trigger(ch chan struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}

// watchGPG fires a check whenever a shadowed key file is opened by the agent.
func watchGPG(files []string, req chan struct{}) {
	mask := uint32(syscall.IN_OPEN | syscall.IN_DELETE_SELF | syscall.IN_MOVE_SELF)
	for {
		fd, err := syscall.InotifyInit1(syscall.IN_CLOEXEC)
		if err != nil {
			log.Printf("GPG: inotify init failed: %v", err)
			return
		}
		watched := 0
		for _, f := range files {
			if _, err := syscall.InotifyAddWatch(fd, f, mask); err != nil {
				log.Printf("GPG: cannot watch '%s': %v", f, err)
				continue
			}
			watched++
		}
		if watched == 0 {
			syscall.Close(fd)
			return
		}

		ch := make(chan inEvent, 16)
		go readLoop(fd, ch)

		recreate := false
		for ev := range ch {
			if ev.Mask&syscall.IN_OPEN != 0 {
				trigger(req)
			} else { // IN_DELETE_SELF / IN_MOVE_SELF: file rotated, rebuild watch
				log.Printf("GPG: key file changed (mask=%#x), recreating watcher", ev.Mask)
				recreate = true
				break
			}
		}
		syscall.Close(fd)
		if !recreate {
			return
		}
		time.Sleep(5 * time.Second)
	}
}

// checkGPGOnRequest mirrors upstream: on a request, wait 200ms, then issue a
// blocking Assuan LEARN. If it takes longer than 400ms the card is busy
// (waiting for touch) -> GPG_ON; emit GPG_OFF once it returns.
func checkGPGOnRequest(req <-chan struct{}, agentSocket string, hub *Hub) {
	for range req {
		done := make(chan error, 1)
		t := time.AfterFunc(400*time.Millisecond, func() {
			hub.Send(GPG_ON)
			if err := <-done; err != nil {
				log.Printf("GPG: agent error: %v", err)
			}
			hub.Send(GPG_OFF)
		})

		time.Sleep(200 * time.Millisecond) // let gpg start talking to scdaemon
		err := assuanLearn(agentSocket)
		if !t.Stop() {
			// Timer already fired (GPG_ON sent); hand the result to that path.
			done <- err
		}
	}
}

// assuanLearn speaks the Assuan protocol directly over the gpg-agent socket and
// blocks until LEARN completes. Replaces gpgme's ctx.AssuanSend("LEARN").
func assuanLearn(socketPath string) error {
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return err
	}
	defer conn.Close()

	r := bufio.NewReader(conn)
	if _, err := r.ReadString('\n'); err != nil { // server greeting
		return err
	}
	if _, err := conn.Write([]byte("LEARN\n")); err != nil {
		return err
	}
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return err
		}
		line = strings.TrimRight(line, "\r\n")
		switch {
		case strings.HasPrefix(line, "OK"):
			return nil
		case strings.HasPrefix(line, "ERR"):
			return fmt.Errorf("assuan: %s", line)
		case strings.HasPrefix(line, "INQUIRE"):
			// Decline any inquiry so we don't hang.
			if _, err := conn.Write([]byte("END\n")); err != nil {
				return err
			}
		}
		// D/S/# lines: keep reading.
	}
}

// watchSSH proxies SSH_AUTH_SOCK (typically gpg-agent's ssh socket) and fires
// a GPG check on any traffic. Port of detector/ssh.go.
func watchSSH(req chan struct{}) {
	socketFile := os.Getenv("SSH_AUTH_SOCK")
	if socketFile == "" {
		if out, err := exec.Command("gpgconf", "--list-dirs", "agent-ssh-socket").Output(); err == nil {
			socketFile = strings.TrimSpace(string(out))
		}
	}
	if socketFile == "" {
		if rd := os.Getenv("XDG_RUNTIME_DIR"); rd != "" {
			socketFile = path.Join(rd, "gnupg/S.gpg-agent.ssh")
		}
	}
	if socketFile == "" {
		log.Print("SSH: no socket to watch (SSH_AUTH_SOCK/gpgconf/XDG_RUNTIME_DIR all empty)")
		return
	}
	if _, err := os.Stat(socketFile); err != nil {
		log.Printf("SSH: socket '%v' does not exist: %v", socketFile, err)
		return
	}

	original := socketFile + ".original"
	if _, err := os.Stat(original); err == nil {
		log.Printf("SSH: '%v' already exists, recovering from a previous crash", original)
		if err := os.Remove(socketFile); err != nil {
			log.Printf("SSH: cannot remove '%v': %v", socketFile, err)
			return
		}
	} else if err := os.Rename(socketFile, original); err != nil {
		log.Printf("SSH: cannot move original socket aside: %v", err)
		return
	}

	restore := func() {
		if err := os.Rename(original, socketFile); err != nil {
			log.Printf("SSH: cannot restore original socket: %v", err)
		}
	}

	proxy, err := net.Listen("unix", socketFile)
	if err != nil {
		log.Printf("SSH: cannot listen on proxy socket: %v", err)
		restore()
		return
	}
	log.Print("SSH: watcher established")

	onExit(func() {
		proxy.Close()
		restore()
	})

	for {
		client, err := proxy.Accept()
		if err != nil {
			if !strings.Contains(err.Error(), "use of closed network connection") {
				log.Printf("SSH: accept error: %v", err)
			}
			return
		}
		upstream, err := net.Dial("unix", original)
		if err != nil {
			log.Printf("SSH: cannot dial original socket: %v", err)
			client.Close()
			return
		}
		go pipe(client, upstream, req)
		go pipe(upstream, client, req)
	}
}

func pipe(src, dst net.Conn, req chan struct{}) {
	defer src.Close()
	defer dst.Close()
	buf := make([]byte, 10240)
	for {
		n, err := src.Read(buf)
		if err != nil {
			return
		}
		if _, err := dst.Write(buf[:n]); err != nil {
			return
		}
		trigger(req)
	}
}

// ---------------------------------------------------------------------------
// Unix socket notifier (port of notifier/unix_socket.go, no systemd activation)
// ---------------------------------------------------------------------------

func setupUnixSocket(hub *Hub) {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		log.Print("socket: $XDG_RUNTIME_DIR not set, unix socket notifier disabled")
		return
	}
	socketFile := path.Join(dir, "yubikey-touch-detector.socket")
	if _, err := os.Stat(socketFile); err == nil {
		log.Printf("socket: '%v' exists, assuming stale and removing", socketFile)
		if err := os.Remove(socketFile); err != nil {
			log.Printf("socket: cannot remove stale socket: %v", err)
			return
		}
	}

	l, err := net.Listen("unix", socketFile)
	if err != nil {
		log.Printf("socket: cannot listen: %v", err)
		return
	}
	log.Printf("socket: listening on %v", socketFile)
	onExit(func() { l.Close(); os.Remove(socketFile) })

	for {
		conn, err := l.Accept()
		if err != nil {
			if !strings.Contains(err.Error(), "use of closed network connection") {
				log.Printf("socket: accept error: %v", err)
			}
			return
		}
		hub.addClient(conn)
		// Drop the client when it disconnects (detected on read EOF).
		go func(c net.Conn) {
			buf := make([]byte, 1)
			for {
				if _, err := c.Read(buf); err != nil {
					hub.dropClient(c)
					return
				}
			}
		}(conn)
	}
}

// ---------------------------------------------------------------------------
// Built-in Sway bar (swaynag). Shows a red bar while any YubiKey touch is
// pending and removes it once everything resolves. Reference-counts by source
// ("GPG"/"U2F"/"MAC") so overlapping requests don't clear the bar early.
// ---------------------------------------------------------------------------

func runSwaynagBar(events <-chan Message, message, edge, color string) {
	pending := make(map[string]struct{})
	var cmd *exec.Cmd
	dead := make(chan *exec.Cmd, 8) // a spawned bar reports its own exit here

	show := func() {
		if cmd != nil {
			return
		}
		c := exec.Command("swaynag",
			"--message", message,
			"--edge", edge,
			"--background", color,
			"--text", "ffffff",
			"--border", color,
			"--border-bottom", "ffffff",
		)
		if err := c.Start(); err != nil {
			log.Printf("bar: cannot start swaynag: %v", err)
			return
		}
		cmd = c
		go func(c *exec.Cmd) { _ = c.Wait(); dead <- c }(c)
	}

	hide := func() {
		if cmd == nil {
			return
		}
		_ = cmd.Process.Signal(syscall.SIGTERM)
		cmd = nil
	}

	onExit(func() {
		if cmd != nil && cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGTERM)
		}
	})

	for {
		select {
		case m := <-events:
			s := string(m)
			if len(s) != 5 {
				continue
			}
			if strings.HasSuffix(s, "1") {
				pending[s[:3]] = struct{}{}
			} else {
				delete(pending, s[:3])
			}
			if len(pending) > 0 {
				show()
			} else {
				hide()
			}
		case c := <-dead:
			// Only clear if it's the bar we currently track; a stale exit from
			// a previously killed bar must not orphan a freshly spawned one.
			if c == cmd {
				cmd = nil
			}
		}
	}
}

// ---------------------------------------------------------------------------

func main() {
	var verbose, stdout, noSocket, noBar bool
	var barMsg, barEdge, barColor string
	flag.BoolVar(&verbose, "v", false, "enable debug logging on stderr")
	flag.BoolVar(&stdout, "stdout", false, "print events to stdout")
	flag.BoolVar(&noSocket, "no-socket", false, "disable the unix socket notifier")
	flag.BoolVar(&noBar, "no-bar", false, "disable the built-in Sway swaynag bar")
	flag.StringVar(&barMsg, "bar-message", "🔐  Touch your YubiKey", "swaynag bar text")
	flag.StringVar(&barEdge, "bar-edge", "bottom", "swaynag bar edge: top or bottom")
	flag.StringVar(&barColor, "bar-color", "d00000", "swaynag bar background color (RRGGBB)")
	flag.Parse()

	log.SetFlags(log.LstdFlags)
	if !verbose {
		log.SetOutput(devNull{}) // quiet by default, like upstream's non-verbose mode
	}
	log.Print("Starting YubiKey touch detector")

	hub := NewHub(stdout)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sig
		runCleanup()
		os.Exit(0)
	}()

	if !noSocket {
		go setupUnixSocket(hub)
	}
	if !noBar {
		if _, err := exec.LookPath("swaynag"); err != nil {
			fmt.Fprintln(os.Stderr, "warning: swaynag not found in PATH; the Sway bar will not show (pass -no-bar to silence)")
		}
		go runSwaynagBar(hub.Subscribe(), barMsg, barEdge, barColor)
	}
	go watchU2F(hub)
	go watchHMAC(hub)
	initGPGDetectors(hub)

	select {} // run forever
}

// devNull discards log output when not in verbose mode.
type devNull struct{}

func (devNull) Write(p []byte) (int, error) { return len(p), nil }
