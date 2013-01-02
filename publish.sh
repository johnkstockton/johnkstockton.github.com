#!/bin/sh
# Push source branch
git checkout source
git add -A
git commit
git push origin source

echo 'Pushing the source to github'

# Push master branch
jekyll
git checkout master
git rm -qr .
cp -r _site/. .
rm -r _site
git add -A
git commit 'update'
git push origin master

echo 'Published successfully.'

# And get back to source
git checkout source
