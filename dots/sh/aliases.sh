#!/bin/bash

alias ls='ls --color=auto'
alias sysu='systemctl --user'
alias tmuxls='tmux list-sessions'
alias tmuxgo='tmux attach-session -t'
alias tmuxnew='tmux new-session -s'
alias tsw='tmux split-window'

alias open='xdg-open'

tmux-change-prefix() {
  tmux set -g prefix C-b
}

find-large-dirs() {
  du -sh * | sort -hr | head -n30
}

find-large-files() {
  N=${1:-10}
  find . -type f -exec du -h {} + | sort -rh | head -n $N
}

tmuxclean() {
  tmux list-sessions | grep -v attached | grep "^[0-9]" | cut -d: -f1 |  xargs -t -n1 tmux kill-session -t
}

alias l='ls -l --color=auto' #for default osx ls add G for color
alias la='ls -Al --color=auto'
alias ll='ls -lah --color=auto'
alias tree='tree -C'
alias trls='tree -C | less -R'	# -C outputs colour, -R makes less understand color
alias dir='ls --format=vertical'
alias vdir='ls --format=long'

# if type gls &>/dev/null;
# then
#     alias ls='gls $LS_OPTIONS '
# else
#     alias ls='ls $LS_OPTIONS '
# fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='echo "Okay, this is just getting ridiculous."'

#Say the magic word
alias s='sudo'

# Reload .bashrc
alias refresh='. ~/.bashrc'

alias aah='ssh -A '

alert-i3 () {
  SOCK=`find /run/user/$(id -u)/i3 -type s`
  i3-msg -s ${SOCK} "exec '/usr/bin/i3-nagbar' -m \"$1\""
}

#########################################
# Dev Tools                             #
#########################################

# SHA1 check
alias sha1='openssl sha1'

gcompu() {
  git commit -am "$1" && ggpush
}

newb() {
  git checkout -b "jamesob/$1"
}

gshow() {
  git show --color-moved=dimmed-zebra  --color-moved-ws=ignore-all-space
}

# Git Aliases
alias gs='git status'
alias ga='git add'
alias gb='git branch'
alias gc='git commit'
alias gd='git diff --color'
alias gmm='git merge master'
alias gclean='git clean -df .'
alias gca='git commit -a'
alias gcam='git commit -am'
alias grhh='git reset --hard HEAD'
alias gpush='git push'
alias gpf='git push --force-with-lease'
alias gpull='git pull'
alias cont='git rebase --continue'

alias gg="git grep"

git-resign-branch() {
  git rebase "$(git merge-base HEAD master)" --exec 'git commit --amend -S --no-edit'
}

git-commits-on-branch() {
  git log $@ --oneline $(git merge-base upstream/master HEAD)..HEAD
}

# GIT heart FZF
# -------------

is_in_git_repo() {
  git rev-parse HEAD > /dev/null 2>&1
}

fzf-down() {
  fzf --height 50% --min-height 20 --border --bind -:toggle-preview "$@"
}

_gf() {
  is_in_git_repo || return
  git -c color.status=always status --short |
  fzf-down -m --ansi --nth 2..,.. \
    --preview '(git diff --color=always -- {-1} | sed 1,4d; cat {-1})' |
  cut -c4- | sed 's/.* -> //'
}

_gb() {
  is_in_git_repo || return
  git branch -a --color=always | grep -v '/HEAD\s' | sort |
  fzf-down --ansi --multi --tac --preview-window right:70% \
    --preview 'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1)' |
  sed 's/^..//' | cut -d' ' -f1 |
  sed 's#^remotes/##'
}

grecent() {
  is_in_git_repo || return
  git to $(git for-each-ref --count=20 --color=always --sort=-committerdate refs/heads/ --format="%(refname:short)" | \
    grep -v '/HEAD\s' | sort | \
        fzf-down --ansi --multi --tac --preview-window right:70% --preview 'git log --color=always {}'
  )
}

_gt() {
  is_in_git_repo || return
  git tag --sort -version:refname |
  fzf-down --multi --preview-window right:70% \
    --preview 'git show --color=always {}'
}

_gh() {
  is_in_git_repo || return
  git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" --graph --color=always |
  fzf-down --ansi --no-sort --reverse --multi --bind 'ctrl-s:toggle-sort' \
    --header 'Press CTRL-S to toggle sort' \
    --preview 'grep -o "[a-f0-9]\{7,\}" <<< {} | xargs git show --color=always' |
  grep -o "[a-f0-9]\{7,\}"
}

_gr() {
  is_in_git_repo || return
  git remote -v | awk '{print $1 "\t" $2}' | uniq |
  fzf-down --tac \
    --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" {1}' |
  cut -d$'\t' -f1
}

_gs() {
  is_in_git_repo || return
  git stash list | fzf-down --reverse -d: --preview 'git show --color=always {1}' |
  cut -d: -f1
}

# Ubuntu/Debian
alias sag='sudo apt-get'
alias sagi='sudo apt-get install'
alias apts='apt-cache search'

alias ack='ack-grep'

function split_pdf() {
  convert -quality 100 -density 300x300 -type Grayscale "$1" "$1%d.jpg"
}

alias psg='ps aux | grep -i'

alias listvms='vboxmanage list runningvms'

alias docker_rm_old="docker ps -a | grep Exited | cut -d' ' -f1 | xargs docker rm"

# D'oh
alias cim='vim'

alias d.='desk .'

alias dc='docker compose'

ghclone() {
  cd ~/src; git clone git@github.com:"$1/$2".git; cd $2
}

irc() {
  FREENODE_PASSWORD=$(pass Local/irc.freenode.net) irssi
}

clearnotis() {
  killall notify-osd
}

# Journaling
# -----------------------------------------------------------------------------
#
newmd() {
  NAME="`date +%Y-%m-%d`-${1}.md"
  $EDITOR $NAME
  echo "$(pwd)/${NAME}"
}

newtxt() {
  NAME="`date +%Y-%m-%d`-${1}.txt"
  $EDITOR $NAME
  echo "$(pwd)/${NAME}"
}

scratch() {
  TMP=$(mktemp)
  vim $TMP
  cat $TMP
  rm $TMP
}

# kernie manipulation
# -----------------------------------------------------------------------------

showkernelpkgs() {
  dpkg --list | grep linux-image
}

# then, to prune do something like
# for i in $(dpkg --list | grep linux-image | grep -v $(uname -r) | cut -d' ' -f3); do sudo apt-get purge --yes $i; done

# systemd control

logu() {
  journalctl --user-unit "$@"
}

alias tldr='tldr -s https://raw.github.com/jamesob/tldr/master/pages'

# btc
# -----------------------------------------------------------------------------

btcprice() {
  curl -sSL https://api.coinbase.com/v2/prices/spot\?currency\=USD \
    | jq -r ".data.amount"
}

usd_to_satoshis() {
  PRICE=$(btcprice)
  echo $((100000000 * $1 / $PRICE))
}

count_cpp_classes() {
  for cls in $(grep -REo "^(class|struct)\s+\S+[^;]" . | cut -d' ' -f2 | tr -d ":" | sort -u); do
    echo "$(rc -z --references-name $cls | wc -l) $cls"
  done
}

count_locks() {
  IFS=$'\n'; for lock in $(rc -a -F "cs_*"); do
    LOC=$(echo $lock | awk -F ':\t' '{print $1}')
    NAME=$(echo $lock | awk -F ':\t' '{print $2}' | sed -r 's/^[ ]+//')
    echo "$(rc -r $LOC | wc -l) $NAME"
  done
}

count_locks_to_file() {
  count_locks | tee locks.txt
  echo
  cat locks.txt | sort -un
}

alias nvim='c nvim'

vi-aliases() {
  vim ~/.sh/aliases.sh
}

vi-dots() {
  cd ~/dotfiles; nvim ~/dotfiles; cd -
}

vi-sway() {
  vim -p ~/dotfiles/dots/config/sway/config ~/.config/sway/config.d/*
}

vi-ctrl() {
  vim -p `which ctrl` ~/dotfiles/pkgs.py
}

vi-c() {
  vim `which c`
}

remind-me() {
  echo "/usr/bin/swaynag -m '$1'" | at "${@:2}"
}

remind() {
  remind-me "$1" now + "$2"
}

new-project() {
  if [ -d "${HOME}/Dropbox/code" ]; then
    mkdir "${HOME}/Dropbox/code/${1}"
    ln -s "${HOME}/Dropbox/code/${1}" "${HOME}/src/${1}"
  else
    mkdir "~/src/${1}"
  fi

  cd "~/src/${1}"
}

dotfiles-commit() {
  cd ~/dotfiles && git diff && git commit -a && gpush; cd -
}

quiet() {
  "$@" >/dev/null 2>&1
}

# First arg is the branch name (on the other remote)
jrni-pr-review() {
  if [ -z "$1" ]; then echo "Need PR #"; exit 1; fi
  if [ -z "$2" ]; then echo "Need remote name"; exit 1; fi
  if [ -z "$3" ]; then echo "Need branch name"; exit 1; fi

  if ! quiet "git remote -v | grep $2"; then
    git remote add "$2" "git@github.com:$2/bitcoin"
  fi
  git fetch "$2"
  git checkout "$3"

  COMMITS=$(
    git log --format=oneline --abbrev-commit --no-merges "$3" ^master | \
      tac | \
      sed -e 's/^/- [ ] /g'
    )
  echo "$COMMITS" | jrni n --stdin --tags bitcoin,pr-review,"$2" review-"$1"-"$2"
}

jrn() {
    vim ~/sync/org/journal.md +$ -c 'normal zz'
}

# -----------------------------------------------------------------------------
# VPN configuration
# -----------------------------------------------------------------------------

nmcli-set-conn-dns() {
  nmcli con mod $1 ipv4.dns $2
  nmcli con mod $1 ipv4.ignore-auto-dns yes
}

generate-password() {
  </dev/urandom tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | head -c "${1:-32}"  ; echo
}

wifi-scan() {
  nmcli dev wifi list
}

wifi-connect() {
  PASSW=
  if [ -z "$2" ]; then
    PASSW="password $2"
  fi
  nmcli dev wifi con "$1" $PASSW
}

get-soundcloud-likes() {
  c ytdl -- --playlist-items '1-10' https://soundcloud.com/jamesob/likes
}

# -----------------------------------------------------------------------------
# Misc
# -----------------------------------------------------------------------------

function pretty_csv {
  column -t -s, "$@" | less -F -S -X -K
}


# Diff the names of files inside directories.
diff-dirs() {
  find $1 -type f -printf "%P\n" | sort > /tmp/__dir1
  find $2 -type f -printf "%P\n" | sort > /tmp/__dir2
  diff -u /tmp/__dir1 /tmp/__dir2
}


# On keyboard: changemod 4
# On teller laptop: changemod 1
changemod () {
  unset I3SOCK
  echo "i3wm.mod: Mod$1" | xrdb -merge
  i3-msg restart
}

rolldice() {
  cat <(history 1000) <(date) | sha256sum | cut -d' ' -f1 \
    | python -c 'import sys; print(bin(int(sys.stdin.read(), 16))[2:])' \
    | grep -Eo '...' \
    | python -c 'import sys; print([int(i,2) for i in sys.stdin.readlines() if int(i,2) <= 6])'
}


download-website() {
  printf "Domain? "
  read DOMAIN
  wget \
     --recursive \
     --no-clobber \
     --page-requisites \
     --html-extension \
     --convert-links \
     --restrict-file-names=windows \
     --domains "${DOMAIN}" \
     --no-parent "${1}"
}

# Remove color from shell output
uncolor() {
  sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"
}

fio-speedtest() {
  fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --numjobs=1 --size=4g --iodepth=1 --runtime=60 --time_based --end_fsync=1
}

docker-rm-stopped() {
    docker rm $(docker ps --filter status=exited -q)
}

# Generate passwords
mapg() {
    apg -m 32 -M SCN

}

# Show unused kernel images.
old_kernels() {
  dpkg -l 'linux-image-*' \
    | awk '/^ii/{print $2}' \
    | egrep '[0-9]+\.[0-9]+\.[0-9]+' \
    | grep -v "$(uname -r | cut -d- -f-2)"
}

# Remove unused kernel images.
remove_old_kernels() {
  OLD_KERNELS=$(old_kernels)
  echo "${OLD_KERNELS}" | xargs sudo apt-get -y purge
}

# For use in agent-forwarded SSH sessions to enable yubikey use.
ssh-refresh-auth-sock() {
    # Grab the latest agent file per mtime
    export SSH_AUTH_SOCK=$(find /tmp -name '*agent*' -printf "%T+ %p\n" 2>/dev/null | grep '/ssh-' | sort -r | cut -d' ' -f2 | head -n 1)
}

share-screen-wayland() {
  /usr/libexec/xdg-desktop-portal -r & /usr/libexec/xdg-desktop-portal-wlr
}

set-dns() {
  echo "nameserver ${1:-127.0.0.1}" | sudo tee /etc/resolv.conf
}

alias P='sudo pacman'

push() {
    ( $@ && pushover "success: $@"  ) || pushover "failed: $@"
}

watch-tex() {
  JOBNAME=${1%.tex}
  xelatex -halt-on-error -shell-escape $1
  evince $JOBNAME.pdf &
  PDF_PS=$!
  RUNTEX="xelatex -halt-on-error -shell-escape $1"
  BIB="$JOBNAME.bib"

  if [ -f "${BIB}" ]; then
      ls $1 | entr -s "rm -f ${BIB} ; $RUNTEX ; biber $JOBNAME ; $RUNTEX ; $RUNTEX"
  else
      ls $1 | entr -s "$RUNTEX"
  fi

  kill ${PDF_PS}
}

mail-vim() {
  [ -z "$1" ] && echo "Need title." && return 1
  cd ~/Documents/mail-drafts
  FILENAME=${HOME}/Documents/mail-drafts/$(date +%Y-%m)-$1
  nvim --cmd "nvim -c 'MailSettings' ${FILENAME}"

  cat $FILENAME

  if which wl-copy >/dev/null 2>/dev/null; then
      cat $FILENAME | wl-copy
      echo
      echo "Copied content to clipboard."
  fi
}
alias vim-mail=mail-vim

newpass() {
  pypass gen $@ | tee /dev/tty | wl-copy
}

desktop-entries() {
  find ~/.local/share/applications
}

# Print when the contents of a directory were last modified.
find-latest-file() {
  LOC=${1:-.}/
  LATEST=$(find $LOC -type f -printf "%T@\0%p\0" | awk '
    {
        if ($0>max) {
            max=$0;
            getline mostrecent
        } else
            getline
    }
    END{print mostrecent}' RS='\0')
  ls -lah --time-style='+%Y-%b-%d %T:%N' ${LATEST}
}

find-latest-file2() {
    find "$1" -type f -printf '%T+ %p\n' | sort -r | head -n 1 | awk '{print $1}'
}

alias get-latest-file=find-latest-file
alias dir-last-modified=find-latest-file

alias gotest="gotestsum -f testname"

dns-refresh() {
    set-dns 1.1.1.1
    sleep 1
    sudo systemctl restart wg-quick@wg0
    sudo systemctl restart dnsmasq
    sleep 2
    set-dns 127.0.0.1
}

archive-wget() {
    domain=$(echo $1 | awk -F'[/:]' '{print $4}')

    wget --recursive --no-clobber --page-requisites \
        --html-extension --convert-links --restrict-file-names=windows \
        --domains "${domain}" --no-parent -P ./archive "$1"

    echo
    echo "Wrote site backup to ./archive"
}

webcam-mpv() {
    mpv av://v4l2:/dev/video0 --profile=low-latency --untimed
}

meditate() {
   if [ -z "$1" ]; then
       echo "need time"
       exit 1
   fi
   mpv ~/music/misc/meditation-bowls.mp3 &
   sleep 6
   kill %%

   echo "meditating..."
   sleep "$(( $1 * 60 ))"
   mpv ~/music/misc/meditation-bowls.mp3
}

webcam-show() {
  ffplay /dev/video0 -input_format mjpeg -fflags nobuffer -flags low_delay -framedrop -video_size 2560x1440
}

webcam-capture() {
    webcam-show
    ffmpeg -f v4l2 -input_format mjpeg -video_size 2560x1440 -i /dev/video0 -vframes 1 output.jpg
}

webcam-qr() {
    webcam-show
    ffmpeg -f v4l2 -input_format mjpeg -video_size 2560x1440 -i /dev/video0 -vframes 1 -f image2pipe -vcodec mjpeg - | zbarimg --raw -
}

ffm-clip() {
  outname=$4
  if [ -z "$outname" ]; then
      outname="${1%.*}-clipped.${1##*.}"
  fi
  ffmpeg -i $1 -ss $2 -to $3 -c copy $outname
}

ffm-webcompress() {
  outname=$2
  if [ -z "$outname" ]; then
      outname="${1%.*}-compressed.${1##*.}"
  fi
  ffmpeg -i $1 -vcodec libx264 -crf 28 -preset fast -acodec aac -b:a 128k -movflags +faststart $outname
}

ffm-cardvdplayer() {
  outname=$2
  if [ -z "$outname" ]; then
      outname="${1%.*}-forcar"
  fi
    ffmpeg -i $1 -vf "scale=720:576" -c:v libxvid -b:v 2000k -c:a libmp3lame -b:a 192k $outname.avi
}

ffm-lengthsplit() {
    if [ -z "$2" ]; then
        echo "Usage: <file in> <out template>"
        return 1
    fi
    ffmpeg -i $1 -c copy -map 0 -segment_time 7000 -f segment -reset_timestamps 1 $2_%03d.mp4
}

latest-screenshot() {
    readlink ~/00_latest_screenshot.png
}

# -----------------------------------------------------------------------------
# Display
# -----------------------------------------------------------------------------

xrandr-ohio() {
  xrandr --auto  # Clear the display
  xrandr --auto --output DP-2 --mode 3840x2160 --right-of eDP-1
}

xrandr-reston() {
  xrandr --auto  # Clear the display
  xrandr --auto --output HDMI-1 --mode 3840x2160 --right-of eDP-1
}

# -----------------------------------------------------------------------------
# GPG/yubikey
# -----------------------------------------------------------------------------

# Sometimes, gpg-agent hangs with yubikey; unfuck with
function gpg-unfuck() {
  gpgconf --kill gpg-agent
  gpg-connect-agent updatestartuptty /bye
}

# When using multiple yubikeys that contain the same subkeys, it is necessary to
# run this when interchanging devices.
yubikey-learnkeys() {
  gpg-unfuck
  gpg-connect-agent "scd serialno" "learn --force" /bye
}
