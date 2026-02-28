---
layout: post
title: JSON web container
image: assets/c.jpg
---

What if you could take the web, turn it into a native app component, and plug it into native layout/scrollview along with other native components? Like magic!

<img src='/assets/c.jpg'>

<br>

Meet [JSON Web Container](http://jasonette.com/webcontainer/). Here's how it works:

<b>Step 1. Write HTML:</b>
Write HTML just like you would make a website, using HTML, Javascript, CSS, or whatever. As long as it works in a browser, it will work as a web container.

<b>Step 2. Write JSON:</b>
Write JSON to describe how it blends into native app layout. You can even style it just like any other component!

<b>Step 3. Enjoy!</b>

Here's an example:
<br>

<img src='/assets/header.png'>

<br>

Check out this video and you’ll realize how much more you can do with this:

<br>

<div class = 'vid'>
  <div class='video-container'>
    <iframe width="1280" height="720" src="https://www.youtube.com/embed/D6Jm_MLnnTE" frameborder="0" allowfullscreen></iframe>
  </div>
</div>

<br>

This is a simple update but simultaneously a huge deal for Jasonette, because it opens door to all kinds of new possibilities.

<br>

# How this came to be

It all started with [Brad](https://github.com/brad).

Just like any developer, I believed web would never work in a native app. We **did** kind of have a half-assed 'html' component with the first version of Jasonette, but it was very limited and was just a hack to display a small subset of HTML elements. 

Most importantly, it didn't have Android support (I never implemented an Android counterpart because I really didn't see much utility from the iOS version so didn't want to invest time).

Then one day I see a new [pull request](https://github.com/Jasonette/JASONETTE-Android/pull/43) on the Android repository:

<img src='/assets/htmlpr.png' class='bordered'>

Obviously I was super skeptical at first ("Everyone knows web views suck!").

But then I actually tried it out.....  I was shocked to find how smooth it was. Whole bunch of web views were scrolling within a list view just fine!

So eventually I got around to converting the iOS HTML component to use the same approach.

Also on top of that I made some improvements and design decisions to make sure that these "web containers" will feel completely native inside our apps. I also added support for Javascript.

Adding Javascript opened doors to all kinds of crazy things:

<img src='/assets/anime.gif' class='col-6'>
<img src='/assets/gauge.gif' class='col-6'>
<img src='/assets/particles.gif' class='col-6'>
<img src='/assets/phaserjs.gif' class='col-6'>
<img src='/assets/rotate.gif' class='col-6'>
<img src='/assets/threejs.gif' class='col-6'>
<img src='/assets/threejstwo.gif' class='col-6'>
<img src='/assets/feed.gif' class='col-6'>


# Performance

Once I had a prototype running I posted it on [the forum](https://forum.jasonette.com) and I got lots of great feedback. One was something I hadn't thought of before:

<img src='/assets/htmlforum.png' class='bordered'>

This comment made me realize that all remote assets (like javascript libraries or css) were being loaded separately for each web container, which resulted in tons of duplicate downloads AND slowdown.

So I went back and added caching mechanism to improve this. So now, all the static assets are cached so they don't get redownloaded multiple times.

After all this was done, the web container was performing flawlessly on both iOS and Android.

<b>In fact, sometimes you can't even tell if it's a native component or a web container!</b>

To sum up: Peformance is great! Of course it won't be 100% the performance of native, but the whole point is to mix and match this into your native app, not to power the entire app using HTML (we're building a native app here!). You have never been able to do something like this before (Seamlessly integrate web views into native scroll views, native layouts, native background, and **use them as native components**) and that makes tons of difference.

<br>

# Conclusion

The moral of this story is, **"Always push the boundary"**. With Jasonette we're doing something that most people will say is crazy ("it will never work!") anyway, so why not go all out!

Also I think the way this feature came together is really awesome because this could only happen because the project was open for contribution. Thanks Brad!

<b>I encourage you to feel free to send pull requests no matter how crazy it is.</b>

And that's it! I'm sure this will take your native app to the next level. The initial release for web container is intentionally minimal, and we'll probably add more powerful features going forward.

Would [appreciate](https://jasonette.now.sh/) [feedback](https://forum.jasonette.com/)!

TODO:

- [Check out the feature landing page](http://jasonette.com/webcontainer)
- [Check out the documentation here](http://docs.jasonette.com/web/)
- [Try the web container demo on Jasonpedia](https://raw.githubusercontent.com/Jasonette/Jasonpedia/gh-pages/webcontainer/index.json)
