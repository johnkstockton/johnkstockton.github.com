#!/bin/sh
# Push source branch
git checkout source
git add -A
git commit
git push origin source

# Push master branch
jekyll
git checkout master
git rm -qr .
cp -r _site/. .
rm -r _site
git add -A
git commit 'update'
git push origin master
