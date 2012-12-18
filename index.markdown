---
layout: default
title: "qf blog"
---

<div class="posts">
    {% for post in site.posts %}
        <article>
          <header>
              <span class='post-date'>{{ post.date | date: "%B %e, %Y" }}</span> 
              <h3 class='post-title'>
                <a href="{{ post.url }}">{{ post.title }}</a>
              </h3>
          </header>
          <div class="body-text">
            {{ post.content }}
          </div>

        </article>
    {% endfor %}
</div>
