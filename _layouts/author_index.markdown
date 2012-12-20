---
layout: default
---

<h2 class="type-title"><span class='type'>Author:</span> {{ page.author }}</h2>

<div class="posts">
    {% for post in site.posts %}
      {% if post.author == page.author %}
        {% include article.html %}
      {% endif %}
    {% endfor %}
</div>
