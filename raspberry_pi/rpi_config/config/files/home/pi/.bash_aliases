# Shortcuts for changing to certain favorite directories

# Shortcut for the history command (tip: use !nn to re-execute a command line by its number)
alias h=history

# If these are enabled they will be used instead of any instructions
# they may mask.  For example, alias rm='rm -i' will mask the rm
# application.  To override the alias instruction use a \ before, ie
# \rm will call the real rm not the alias.

# Interactive operation...
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'

# Default to human readable figures
alias df='df -h'
alias du='du -h'

# Misc :)
# alias less='less -r'                          # raw control characters
# alias whence='type -a'                        # where, of a sort
alias grep='grep --color'                     # show differences in color
alias egrep='egrep --color=auto'              # show differences in color
alias fgrep='fgrep --color=auto'              # show differences in color

# long-list (ls with some common options)
# -l long format (one item per line)
# -h human-readable file sizes
# -a all files (incl. hidden files and parent folders)
alias ll='ls -lha --color=auto'


