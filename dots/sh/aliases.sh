#!/bin/bash

alias sysu='systemctl --user'
alias tmuxls='tmux list-sessions'
alias tmuxgo='tmux attach-session -t'
alias tmuxnew='tmux new-session -s'
alias tsw='tmux split-window'

tmux-change-prefix() {
  tmux set -g prefix C-b
}

find-large-dirs() {
  du -sh * | sort -hr | head -n30
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

alias docker_rm_old="docker ps -a | grep Exited | cut -d' ' -f1 | xargs docker rm"
    
# D'oh
alias cim='vim'

alias d.='desk .'

alias dc='docker-compose'

ghclone() {
  if [ ! -d "${HOME}/tmp" ]; then
    mkdir "${HOME}/tmp"
  fi

  cd "${HOME}/tmp"
  git clone git@github.com:"${1}".git
  cd "${1##*/}"
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

ghclone() {
  cd ~/src; git clone git@github.com:"$1/$2".git; cd $2
}

quiet() {
  "$@" >/dev/null 2>&1 
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

# Generate passwords
mapg() {
    apg -m 32 -M SCN

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

alias get-latest-file=find-latest-file
alias dir-last-modified=find-latest-file

alias gotest="gotestsum -f testname"

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
