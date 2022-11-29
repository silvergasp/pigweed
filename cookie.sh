eval 'set +o history' 2>/dev/null || setopt HIST_IGNORE_SPACE 2>/dev/null
 touch ~/.gitcookies
 chmod 0600 ~/.gitcookies

 git config --global http.cookiefile ~/.gitcookies

 tr , \\t <<\__END__ >>~/.gitcookies
pigweed.googlesource.com,FALSE,/,TRUE,2147483647,o,git-nathaniel.brough.gmail.com=1//0ffFrBouWobsJCgYIARAAGA8SNwF-L9IrhpoEpJd86sWddnD4pfeFL35bX0vh8Y9zleTZK3-imk2uaRDzmLXigz-r3-4MlcFTIw0
pigweed-review.googlesource.com,FALSE,/,TRUE,2147483647,o,git-nathaniel.brough.gmail.com=1//0ffFrBouWobsJCgYIARAAGA8SNwF-L9IrhpoEpJd86sWddnD4pfeFL35bX0vh8Y9zleTZK3-imk2uaRDzmLXigz-r3-4MlcFTIw0
__END__
eval 'set -o history' 2>/dev/null || unsetopt HIST_IGNORE_SPACE 2>/dev/null

