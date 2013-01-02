#!/bin/sh
# Push source branch
git checkout source
git add -A
git commit
git push origin source

clear

echo '  '
echo '  '
echo '  '
echo '  '
echo  "\033[0;36mPushing source to github\033[0m"
echo '  '
echo '  '
echo '  '
echo '  '


# Push master branch
jekyll
git checkout master
git rm -qr .
cp -r _site/. .
rm -r _site
git add -A
git commit 'update'
git push origin master

clear

echo '  '
echo '  '
echo '  '
echo '  '
echo 'Published successfully.'
echo '  '
echo '  '
echo '  '
echo '  '

