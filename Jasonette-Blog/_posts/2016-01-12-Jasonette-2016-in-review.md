---
layout: post
title: Jasonette, 2016 in Review
image: assets/j.png
---

How are apps built?

You write a program and put it on the phone!

But what if you could represent an entire native app as JSON and **load it on demand from the cloud over HTTP**, just like a web page?

![image](http://jasonette.com/images/j.png)

<br>

This little idea consumed the entirety of my life in 2016.

And the result is [Jasonette](https://www.jasonette.com).

Jasonette lets you **build 100% native apps on Android and iOS simply by writing a single JSON markup.** Watch the video below if you haven't yet. Your life will never be the same.

<br>

{% youtube "https://www.youtube.com/watch?v=hfevBAAfCMQ" %}

<br>

When I look back at 2016, it really feels like ages because so many things happened.

But it's crazy to think that it's only been 2 months since I open sourced Jasonette!

Let me share my 2016 with you today.

<br>

## Season 1 Pilot: Jason

Exactly 8 months ago from today, [I released an app called Jason](https://www.producthunt.com/posts/jason). This was a standalone app that was a precursor to Jasonette. You would enter a JSON URL into Jason app's address bar, and it would instantly turn into your own custom app.

<img class='center medium' src='https://s3-us-west-2.amazonaws.com/www.jasonclient.org/intro.gif'>

<br>

A lot of minds were blown:

![twitter](https://pbs.twimg.com/media/CirgXxKXAAEoOXt.jpg:large)

But at the same time, this was one of the most esoteric apps one could build—an app within an app, [a russian doll](https://en.wikipedia.org/wiki/Matryoshka_doll) of sorts—as pointed out below:

![ph](/assets/ph.png)

<br>

I didn't even have a specific set of target users in mind when I built this. I just built it because I could.™

But I looked at all these reactions and thought about it:

1. Other people were amazed that an app can be built this way, and wanted to build their own apps this way too.
2. I wasn't interested in just another way of building apps. I was more interested in lowering the barrier so significantly that it changes the meaning of the term "app".
3. Charging for usage would beat the purpose since that would fail at lowering the barrier.

I knew exactly what I had to do: Jason needed to be open sourced and completely set free.

Well it shouldn't be that hard to open source. After all, I already have a functional code base, right?

Hahaha. 

It took me 6 months.

<br>

## Intermission: Lessons learned from documentation

Once I dived in, I soon realized open sourcing is not just about putting the code out there, but making sure people can understand it easily.

This was especially the case for Jasonette, because without a documented API, no one would be able to know what they can do with it. It would be like releasing a web browser without an HTML spec. Basically, the documentation itself was the product.

And turns out, documentation is not easy. 

{% twitter https://twitter.com/gliechtenstein/status/786284865733877764 %}

<br>

For the next 6 months, I did nothing but documentation and code cleanup.

These were my darkest days. I did nothing but work on the documentation, I wasn't creating something new, I was simply documenting something that already existed and I hated it. But what other options did I have? So I kept at it.

**However, I soon realized that** while frustrating, the process of documenting the project was extremely helpful:

1. I got to understand my own code better.
2. I found a lot of inconsistencies in the API while documenting, which needed to be refactored.
3. I gained a birds-eye point of view of the project, which was crucial when I started working on the Android version later.

But the thing is, the more I documented, the more I had to refactor, and the more I refactored, the more I had to document to reflect the update. By working more, I was creating even more work. At some point I started feeling like a [tortoise chasing after achilles](https://en.wikipedia.org/wiki/Zeno's_paradoxes#Achilles_and_the_tortoise). Would I ever finish this?

In the meantime, I had set up a landing page and kept adding new materials as soon as they were ready, even though I hadn't launched it yet. And somehow people were discovering it and sharing it.

One day when I was begrudgingly working on documenting an [express.js demo app](https://github.com/Jasonette/s3-upload-example) for Jasonette, I saw this tweet.

{% twitter https://twitter.com/tjholowaychuk/status/779092360487546880 %}

What a nice timing! I was very excited, and this encouraging tweet gave me all the strength I needed to finish up the docs and prepare for the launch... which wouldn't happen for another month and a half.

---

## Season 1 Episode 01. Jasonette-iOS

On the morning of 11/4 [I posted on Hacker News](https://news.ycombinator.com/item?id=12879179). It shot up to #1 and stayed #1 the entire day.

Then it went on to become the **#1 Github trending project**. Not too bad for my first ever open source contribution!


![github](/assets/github_trending.png)

---

## Season 1 Episode 02. Jasonette-Android
Upon releasing the iOS version, the most frequently asked question was "Android?". I wasn't surprised, since I knew that was the most obvious next step.

However what I didn't know was how long it would take me to come up with one.

**Or if it would be even possible at all.**

I only knew that Android had a layout system called `LinearLayout` which works similar to `UIStackView` which I used for the iOS version. So I just assumed that it would be possible, but it was really not straightforward.

This time, I decided not to torture myself with 6 months of agony. Instead of trying to make a perfect release, I decided to pick only the most crucial features and commit to releasing version 0 as soon as possible, and go from there.

I set the goal: **Implement the core engine and get it out there, in 1 month.**

And surprisingly, I managed to succeed.

Watch the android version and the ios version side by side. These are loading from exactly the same JSON you can find [here](https://github.com/Jasonette/Instagram-UI-example/blob/master/home.json)

<span class='col-6'><img src='https://cdn-images-1.medium.com/max/1200/1*yHXxTeQFdyWjxPSP2f7ZkA.gif'></span><span class='col-6'><img src='https://cdn-images-1.medium.com/max/1200/1*v9RxUZ-8XzLfDTfI3gmx6A.gif'></span>

---

## Season 1 Finale: Current state of Jasonette community

What excites me the most is that the project has managed to find a great community of people who share the same vision and all contributing to the project in many different ways.

### Open source is magic
I've never worked on open source before so all these contributions from people I've never met still feel surreal to me.

It's really amazing how people from all around the world can come together and collaborate to build something together this easily.

### New features and projects
I went back and took a look at what our community has accomplished during the two months Jasonette has been out, and looks like we did a lot.

Here are some of the **new major features and projects** we've added since the launch (Not including bugfixes or iOS-to-Android feature port because that would make the list huuuge):

- [ 🔥 Jasonette-Android](https://github.com/Jasonette/JASONETTE-Android) - The name says it all. The Android implementation of Jasonette, which makes Jasonette fully cross platform.
- [Android binary size reduction](https://github.com/Jasonette/JASONETTE-Android/issues/13) - Initially the Android binary size was huge, at over 40MB. We've made some optimizations which dropped it down to around 9MB, all the while supporting 100% of the parsers (json, csv, rss, xml, html), thanks for the contribution [@brad](https://github.com/brad)!
- [Push notifications](https://github.com/Jasonette/JASONETTE-iOS/issues/7) - Push notifications on iOS purely powered by JSON. We will soon release this officially once we document the API and implement the Android version.
- [Local JSON](https://github.com/Jasonette/JASONETTE-iOS/pull/42) - This was one of the [most higly requested](https://github.com/Jasonette/JASONETTE-iOS/issues/48) features. Some people wanted to embed a JSON file in their project locally instead of fetching from a remote server. I initially was hesitant but soon became convinced that it can be useful in many cases. Thanks to [@copongcopong](https://github.com/copongcopong) for the implementation!
- [CocoaPods based extension management](https://github.com/Jasonette/JASONETTE-iOS/issues/34) - We had a long discussion thread about this on Github, and in the end, [@seletz](https://github.com/seletz) implemented a solution which worked beautifully. We are currently working on the second iteration of extension management based on the insights we gained from this.
- [Ad integration](https://github.com/Jasonette/JASONETTE-iOS/pull/92) - This was also one of the [most highly requested](https://github.com/Jasonette/JASONETTE-iOS/issues/79) features as well. Thanks to [@wajahatch888](https://github.com/wajahatch888), now we have AdMob support on iOS. [Android support](https://github.com/Jasonette/JASONETTE-Android/issues/22) to come soon :)
- [Deep linking](https://github.com/Jasonette/JASONETTE-iOS/commit/b359ab6d44f88d54ca9a5240f0e62e4ec0ca6852) - Ability to open Jasonette apps using URL scheme (Example: `jasonette://href?url=https://www.jasonbase.com/things/dh3.json`)
- [Log action](https://github.com/Jasonette/JASONETTE-iOS/pull/20) - An action that lets you log anything during execution. Built by [@seletz](https://github.com/seletz).
- [$background event](https://github.com/Jasonette/JASONETTE-iOS/pull/27) - An event to detect when the app goes into background mode. Thanks [@fretz](https://github.com/fretn)!
- [components border](https://github.com/Jasonette/JASONETTE-iOS/pull/30) - Add "border" attribute to component styles. Now, any component can have a border surrounding them, thanks to [@WenchaoD](https://github.com/WenchaoD)!
- [Loading indicator](https://github.com/Jasonette/JASONETTE-iOS/pull/87) - Another great feature addition by [@wajahatch888](https://github.com/wajahatch888). Displays a loading indicator when the content is loading.
- [HTML component for Android](https://github.com/Jasonette/JASONETTE-Android/issues/30) - I had actually left out this feature on Android initially because I wasn't sure how performant it would be to have WebViews as components. [@brad](https://github.com/brad) went on and just built it himself, and turns out that it works super smooth! Now works cross-platform both on iOS and Android.
- [Image button](https://github.com/Jasonette/JASONETTE-iOS/pull/94) - Initially the buttons could only display text. Now it's possible to use image buttons. Both on iOS and Android.


### Other Important Contributions
New features are exciting, but I think what's really important are things that we do to make the project itself much more maintainable and comprehensible so it's easier to work with. This includes:

1. Documentation
2. Adding automation to reduce repetitive tasks
3. Making it easier to work with Jasonette itself

It's still very early days for Jasonette so we lack a lot of these things. And the community is coming up with various solutions. **I especially welcome these contributions with open arms**. Here are some of the highlights we've achieved:

- [Auto-generate documentation using Travis CI](https://github.com/Jasonette/documentation/commit/eb5734484d07b49ec81a70c5eb8c017eaa342412) - As an open source newbie I had no idea you could just automatically generate a documentation, so have been manually doing it. Now it's all automated via [Travis CI](https://travis-ci.org/), thanks to [@gtramontina](https://github.com/gtramontina)!
- [Integration with Code Climate](https://github.com/Jasonette/JASONETTE-iOS/commit/0962d3bd2a7ccec7c091cb42a643055be7a03c6a) - I am learning about all kinds of great tools for maintaining and visualizing open source projects from contributions. [Code Climate](https://codeclimate.com) is really nifty and lets you see problems with the code at a glance. Thanks to [@lukeramsden](https://github.com/lukeramsden) for the integration!
- [Make it easy to use multiple targets in XCode](https://github.com/Jasonette/JASONETTE-iOS/commit/81cf25c9b26fad1e066027e28daa9f13cdaabe3a) - I honestly had never thought about this idea. [@golopupinsky](https://github.com/golopupinsky) found that it becomes tedious to use one Jasonette project to build multiple apps, and just came up with a solution, and I think it will be super useful for people who want to juggle between building multiple apps using a single Jasonette project file.

---

## What next in 2017? - Season 2 Preview

2016 was just the beginning. Our community is working on a lot of exciting things, and we plan to release tons of mind-blowing things in 2017. Here are some examples:

### Oauth
This will be amazing once we roll out officially. It will be one of the most powerful features of Jasonette. Stay tuned :)

### Package Manager
Jasonette was [designed to be extensible](http://docs.jasonette.com/advanced/#extension). However, while writing an extension for personal usage has been easy, it has always been difficult to share and distribute because of all the dependency management we had to deal with.

After having tried multiple approaches to managing extensions, we've finally found the best way to make writing extensions dead simple. We are still working on it and plan to release it soon.

Expect to see a lot of cool additional features powered by JSON in 2017. 

### Lambda
I'll leave this up to your imagination :)

All I have to say is that this will take jasonette to the next level.

### Much more
Of course, there are a lot of other cool projects which are still work in progress but I won't mention them here just to keep the mystery 😁 

Follow our project to stay updated!

---

## Join us.

Sound exciting? join us on [slack](https://jasonette.now.sh/), [forum](https://forum.jasonette.com/), [twitter](https://twitter.com/jasonclient)!

Also, follow and contribute to the project on Github: [Jasonette-Android](https://github.com/Jasonette/JASONETTE-Android), [Jasonette-iOS](https://github.com/Jasonette/JASONETTE-iOS)

**And most importantly, [Go build awesome things with it!](https://www.jasonette.com)**

![Join us](/assets/join.png)
