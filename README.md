
Arch related dotfiles adapted from: https://github.com/mylinuxforwork/dotfiles see branch `old_macOS_mylinuxforwork`

- Most recent arch dotfiles are now in their own repo [archdotfiles](https://github.com/adam-coates/archdotfiles)

- Repo here is specifically for use for either macOS and using neovim on windows 


- Current setup works on macOS so need to check paths on windows!! 
    e.g. `/Users/adam/` (macOS) = `C:/Users/*name*` (windows)
    e.g. `~/.config` (macOS) = `C:/Users/*name*/AppData/local` (windows)


- For windows the installation will involve extra tinkering and likely the removal of some plugins (e.g. image.lua)



- Ngram database downloaded from here: 
    [Ngram database](https://languagetool.org/download/ngram-data/)

- Current set-up for writing notes uses a mixture of the following: 
    - Native nvim spell checking
    - Vale - for grammar checking 
    - ~~Harper - for grammar checking~~ (removed harper as its bloat. May switch back to since ltex-ls uses quite some resources)
    - Ltexls - for grammar checking (and some spelling) 

