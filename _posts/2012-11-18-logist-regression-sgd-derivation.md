---
layout: post
title: "logistic regression SGD derivation"
published: true
tags:
    - ML
---

Its tough to find a good online walkthrough of the derivation for gradient descet
with logistic regression.  Most either only discuss linear regression, or just
give the final update rule, without walking through the steps.  These are decent:

* [Andrew Ng's Course Notes](http://cs229.stanford.edu/notes/cs229-notes1.pdf)
* [Simple Derivation of Logistic Regression](http://www.win-vector.com/blog/2011/09/the-simpler-derivation-of-logistic-regression/) from the WinVector blog.  Doesn't give you the SGD update rule, but does the hard work of finding the gradient.  Great discussion of logistic regression in general, too.
* [Notes From Jason Rennie](http://people.csail.mit.edu/jrennie/writing/lr.pdf).  This also includes Newton's method & L2 regularization, but skims over details.
