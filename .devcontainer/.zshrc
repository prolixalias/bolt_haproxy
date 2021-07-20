sudo chown -R localdev:localdev ~/.aws ~/.ssh
if [[ ! -a ~/.homesick/repos/dotfiles ]]; then
  if [[ -x "$(command -v homesick)" ]]; then
    mkdir -p ~/.homesick/repos/
    cd ~/.homesick/repos
    git -c http.sslVerify=false clone --recurse-submodules -j2 git@github.com:prolixalias/dotfiles.git
    cd $(homesick show_path)
    git submodule foreach git pull origin main
    homesick rc --force
    [[ -a ~/.homesick/repos/dotfiles ]] && homesick link --force
  fi
fi