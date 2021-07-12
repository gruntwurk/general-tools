# .bashrc file (which is called every time a new bash session 
# starts up, regardless of whether or not a login was required)

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Set Timezone as Pacific Standard Time (GMT minus 8 hours) with Pacific Daylight Time Observed
export TZ=PST8PDT

# HISTIGNORE is a colon-delimited list of patterns which should be excluded.
# [ \t]* suppresses blank lines (nothing but spaces and tabs)
# The '&' is a special pattern which suppresses duplicate entries.
# Ignore the exit and ls commands
export HISTIGNORE=$'[ \t]*:&:[fb]g:exit:ls' 

# Aliases
if [ -f "${HOME}/.bash_aliases" ]; then
  source "${HOME}/.bash_aliases"
fi

