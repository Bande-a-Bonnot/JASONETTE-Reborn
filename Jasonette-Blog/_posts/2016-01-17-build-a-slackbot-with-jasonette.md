---
layout: post
title: Remote-control your Slack bots with JSON
image: assets/coffee_bot_slack.png
---

**Update:** As a mistake I timestamped this as 2016, but this post was just freshly published on January 17th of 2017. Sorry for the confusion! :D 

A couple of days ago, [@shaunymca](https://github.com/shaunymca) shared a really cool project on [our slack channel](https://jasonette.now.sh/).


<img src='/assets/coffeebot.png' class='bordered'>

If you think about it, this is a pretty refreshing idea. Basically, it's **a mobile app for remote-controlling a Slack bot.** 

To declare that you've started brewing coffee, open the app, and simply touch the button from the cell with your name

<img src='/assets/coffeebot_original.png' class='medium bordered'>

And in 12 minutes, 

<img src='/assets/coffee_bot_slack.png' class='bordered'>

And the cool part is, this was built with Jasonette, so **he didn't need to write any native code.**

First, he wrote an express.js server which returns a JSON markup.

Then he connected it to [Jasonette](https://www.jasonette.com), which turned that JSON markup into a native app which drew the UI as well as sent requests to the server upon user input.

And voila! We have a remote control app for Slack bots.

Check out the repo here: [https://github.com/shaunymca/coffeeapp](https://github.com/shaunymca/coffeeapp)

<br>

## Demo
I thought it was really cool so just decided to fork and try it out on our own slack channel. Here's how it works:

When the [Jasonette app](https://jasonette.com) hits the home url, the server returns a JSON markup that looks like this:

![Coffee json](/assets/coffee_json.png)

Then, Jasonette turns it into a native app that looks like this:

<span class='col-6'>
	<span>iOS</span>
	<img src='/assets/coffee_app_ios.png' class='medium bordered'>
</span>
<span class='col-6'>
	<span>Android</span>
	<img src='/assets/coffee_app_android.png' class='medium bordered'>
</span>

So how does it work behind the scenes? Each cell item is represented by a JSON object in the markup, which has an `action` attribute that looks like this:

{% raw %}
```json
{
  "type": "$network.request",
  "options": {
    "url": "https://evening-inlet-32428.herokuapp.com/submit.json",
    "method": "POST",
    "data": {
      "user_name": "{{name}}",
      "user_id": "{{id}}"
    }
  }
}
```
{% endraw %}

When you tap on a cell, it makes a `POST` request to the [submit.json](https://github.com/shaunymca/coffeeapp/blob/master/server.js#L61) endpoint, which [triggers the Slack API](https://github.com/shaunymca/coffeeapp/blob/master/modules/slackPosting.js#L17).

**And in 12 minutes, your Slack channel will get a notification from the Coffee bot!.**

<img src='/assets/coffee_bot_slack.png' class='bordered'>

## TLDR

1. The express server returns a [JSON markup](https://github.com/shaunymca/coffeeapp/blob/master/modules/jsonette.js#L61), which becomes a native app when you connect it with Jasonette.
2. When you tap an item from the app, it triggers a [POST request](http://docs.jasonette.com/actions/#networkrequest) to the server.
3. The server waits 12 minutes, and then triggers the Slack API with credentials to post to the Slack channel.

<br>

## Conclusion

This reminded me of the [Yo app](https://www.justyo.co/), since it's meant to only serve a single purpose.

It's like a bot version of Yo. But for multiplayer. And powered by Slack!

It's awesome to see these creative projects being built with Jasonette. Feel free to [reach out](https://twitter.com/jasonclient) if you built something cool using Jasonette. I will try to showcase them on the blog.

**Lastly, make sure to try out [@shaunymca](https://github.com/shaunymca)'s coffeebot app for your own slack channel! It's so cool! [https://github.com/shaunymca/coffeeapp](https://github.com/shaunymca/coffeeapp).**

---
