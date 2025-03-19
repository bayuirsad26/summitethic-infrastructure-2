# Docker command completion
if [ -f /usr/share/bash-completion/completions/docker ]; then
    . /usr/share/bash-completion/completions/docker
elif [ -f /etc/bash_completion.d/docker ]; then
    . /etc/bash_completion.d/docker
fi

# Docker compose completion
if [ -f /usr/share/bash-completion/completions/docker-compose ]; then
    . /usr/share/bash-completion/completions/docker-compose
elif [ -f /etc/bash_completion.d/docker-compose ]; then
    . /etc/bash_completion.d/docker-compose
fi

# Useful Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs'
alias dclean='docker system prune -f'
alias dpurge='docker system prune -af --volumes'