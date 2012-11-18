---
layout: default
title: "cwoebker"
---

<div class="content">
<div class="posts">
    <h1>Posts</h1>
    <ul>
    {% for post in site.posts %}
        <li>
        <span>Posted on {{ post.date | date: "%B %e, %Y" }}</span> - <a href="{{ post.url }}">{{ post.title }}</a>
        </li>
    {% endfor %}
    </ul>
</div>
<!--{% include articles.html %}-->
</div>