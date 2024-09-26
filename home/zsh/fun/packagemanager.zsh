fuction mI() {
    if command -v yay >/dev/null 2>&1; then
       yay -S $*
    elif command -v pacman >/dev/null 2>&1; then
       sudo pacman -S $*
    elif command -v apt >/dev/null 2>&1; then
       sudo apt install $*
    elif command -v brew >/dev/null 2>&1; then
       sudo brew install $*
    fi
}

fuction mR() {
    if command -v yay >/dev/null 2>&1; then
       yay -R $*
    elif command -v pacman >/dev/null 2>&1; then
       sudo pacman -R $*
    elif command -v apt >/dev/null 2>&1; then
       sudo apt remove $*
    elif command -v brew >/dev/null 2>&1; then
       brew remove $*
    fi
}

fuction mS() {
    if command -v yay >/dev/null 2>&1; then
       yay -Ss $*
    elif command -v pacman >/dev/null 2>&1; then
       pacman -Ss $*
    elif command -v apt >/dev/null 2>&1; then
       apt search $*
    elif command -v brew >/dev/null 2>&1; then
       brew search $*
    fi
}

fuction mH() {
    if command -v yay >/dev/null 2>&1; then
       yay -Qi $*
    elif command -v pacman >/dev/null 2>&1; then
       pacman -Qi $*
    elif command -v apt >/dev/null 2>&1; then
       apt show $*
    elif command -v brew >/dev/null 2>&1; then
       brew info $*
    fi
}

fuction mU() {
    if command -v yay >/dev/null 2>&1; then
       yay -Syu
    elif command -v pacman >/dev/null 2>&1; then
       sudo pacman -Syu
    elif command -v apt >/dev/null 2>&1; then
       sudo apt update && sudo apt upgrade
    elif command -v brew >/dev/null 2>&1; then
       brew update && brew upgrade && brew upgrade --cask
    fi
}

