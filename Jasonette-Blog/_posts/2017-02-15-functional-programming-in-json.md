---
layout: post
title: Designing a Functional Programming Language in JSON
image: assets/halflife.jpg
---

Today, let me show you something you have never seen--**a programming language written in JSON**.

And not just any programming, but **[functional programming](https://en.wikipedia.org/wiki/Functional_programming)**.

![lambda](/assets/halflife.jpg)

Here's the summary of this article:

1. **Anatomy of a function**
2. **How to write a function in JSON**
3. **Expressing function call stacks and return values in JSON**

---

Note: This post discusses the technology behind [Jasonette](https://www.jasonette.com), an open source framework that lets you **make cross-platform mobile apps with just a JSON markup**.

Expressing all of Model-View-Controller logic in pure JSON is not a simple task, and each deserves its own article. I have already written an article about the [view-side logic](https://medium.freecodecamp.com/how-to-build-cross-platform-mobile-apps-using-nothing-more-than-a-json-markup-f493abec1873#.i83lzc4g9).

But in this article, it's all about the **controller logic**. More specifically, functions.

---

<br>

# 1. Anatomy of a function

Programming languages are supposed to carry out useful tasks. Normally these exist in the form of **functions**. Let's take a look at **Javascript** for example.

---

**1. A function has a `name` and `arguments`.**

**Names** let you reference functions in a unique manner.

You pass **Arguments** to functions so they can be processed.

![function](/assets/function_name_arguments.png)

---

**2. `Callback` is when you pass a function as an argument to another function.**

Callbacks are important in any application that involves asynchronous tasks such as network requests, processing user interactions, etc. because you have to delay the callback function's execution until it's time.

![function](/assets/function_callbacks.png)

---

So the question is: How can we use a JSON object to describe things like this?

<br>

# 2. Writing a function in JSON

Jasonette has something called [actions](http://docs.jasonette.com/actions/). Actions describe tasks. Each action consists of up to four attributes:

1. `type`: name of a native function to run
2. `options`: arguments to pass to the function
3. `success`: success callback to run when the function returns success
3. `error`: error callback to run when the function returns error

Using just these four attributes, you can build any kind of fully functional app.

<br>

## Arguments

Functions are not so meaningful without arguments. We want a function to perform different actions based on the arguments we pass to it.

Here we pass `title` and `description` attributes to [$util.alert](http://docs.jasonette.com/actions/#utilalert) action to create a custom alert dialog.

{% raw %}
```
{
  "type": "$util.alert",
  "options": {
    "title": "Basic Alert",
    "description": "I'm a basic alert. I simply display an alert that needs to be dismissed before moving forward"
  }
}
```
{% endraw %}

When you run this action on Jasonette, It displays an alert that looks like the following:

<span class='col-6'>
  <span>iOS</span>
  <img class='bordered medium' src='/assets/alert_ios.png'>
</span>
<span class='col-6'>
  <span>Android</span>
  <img class='bordered medium' src='/assets/alert_android.png'>
</span>

<br>

## Callbacks

Since most things that happen on mobile devices are asynchronous in nature, callbacks are first-class citizens and built into actions on Jasonette.

There are two types of callbacks: `success` and `error`. `success` gets called when the action succeeds. `error` when it fails.

Here's an example of a `success` callback:

{% raw %}
```
{
  "fetch": {
    "type": "$network.request",
    "options": {
      "url": "https://jsonplaceholder.typicode.com/posts"
    },
    "success": {
      "type": "$render"
    }
  }
}
```
{% endraw %}

Here's what it does:

1. Makes a network request ([$network.request](http://docs.jasonette.com/actions/#networkrequest)) to [jsonplaceholder server](https://jsonplaceholder.typicode.com/)
2. Passes that result to its `success` callback action--which is another action called [$render](http://docs.jasonette.com/actions/#render)--which renders the result using whichever template you define (also in JSON).
3. We name the action `fetch` by wrapping it with the key.

<br>

## Evaluation

{% raw %}
Since the native language of JSON is Javascript (JSON is short for JavaScript Object Notation), Jasonette implements evaluation using a built-in Javascript engine. If you want to evaluate something, simply wrap it inside a template expression (`{{ }}`).
{% endraw %}

**Inline Javascript means we can do some crazy stuff like this:**

{% raw %}
```
{
  "fetch": {
    "type": "$network.request",
    "options": {
      "url": "https://.....",
      "method": "POST",
      "data": {
        "guid": "{{var str=$cache.guid; var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='; for ( var block, charCode, idx = 0, map = chars, output = ''; str.charAt(idx | 0) || (map = '=', idx % 1); output += map.charAt(63 & block >> 8 - idx % 1 * 8)) { charCode = str.charCodeAt(idx += 3/4); if (charCode > 0xFF) { throw new InvalidCharacterError('btoa failed'); } block = block << 8 | charCode; } return output;}}"
      }
    },
    "success": {
      "type": "$render"
    }
  }
}
```
{% endraw %}

Here's what's going on:

1. We try to make a network request using the data specified inside `options.data`.
2. But the value of `guid` is a [template expression](http://docs.jasonette.com/templates/), so the interpreter first executes the Javascript inside the template expression to determine the final value.
3. If you look closely at the Javascript code, it takes the `$cache.guid` ([$cache](http://docs.jasonette.com/actions/#cache) is a global variable for persisting data on the device) and **generates a hash from it**. It's basically a manual implementation of javascript's native [btoa function](https://developer.mozilla.org/en-US/docs/Web/API/WindowBase64/Base64_encoding_and_decoding).
4. After all that's done, it finally makes the network request with the final value.
5. Then it calls `$render` via its `success` callback.

<br>

---

# Intermission

**Everything below this point is completely NEW to Jasonette with the latest release.**

---

<br>

# Transition from Message dispatch to Function calls

So far I made it sound like actions on Jasonette are like functions. But it was only half true.

## How it used to work

In the previous versions of Jasonette, every action would terminate immediately after calling its `success` or `error` callback. Here's what a typical action call chain looked like:

1. Action 1 calls Action 2 and terminates.
2. Action 2 does its job, and calls Action 3, then terminates.
3. Action 3 does its job, and calls Action 4, then terminates. etc.

While not perfect, this model works fine because each action callback passes its result onto the next action (packaged as a variable called `$jason`), and as long as each action keeps doing its job correctly and propagates the correct value, the last action in the call chain would end up with expected results.

## Problem

The probelm is, **you can't create subroutines** with this architecture. It's impossible to do something as straight-forward as: 

1. Action 1 calls Action 2 and waits.
2. Action 2 finishes running, and sends a return value back to Action 1.
3. Action 1 picks up where it left off and carries on with the return value from Action 2.

It's impossible because every action immediately terminates after triggering another action--it can't wait for its subroutine to return.

In this sense, calling an `action` was more like a **message dispatch** than a **function**.

Functions have call stacks, their own local states, and most importantly, return values. And there are no such things when you're simply dispatching messages.

Without a way to implement subroutines:

1. **It's impossible to write modular code**
2. **Writing recursive algorithms is not trivial**

<br>

<img src='https://imgs.xkcd.com/comics/functional.png' class='medium'>

This was not a serious problem initially, when most people just used Jasonette to write small apps and prototypes. But as people started to realize they can actually write production apps this way, this became problematic because they started writing thousands of lines. Imagine reading through thousands of lines of JSON code with absolutely no modularity.

<br>

# Expressing function call stacks & return values in JSON

To address this we needed a way for an action to:

1. Invoke another action
2. Wait for the callee action to return, and continue on with the return value once it returns.

Also it would be best **if we didn't invent a new concept just for this, but instead simply come up with just another new action to achieve this.**

So [$lambda](http://docs.jasonette.com/actions/#lambda) and [$return](http://docs.jasonette.com/actions/#returnsuccess) were born.

<br>

## $lambda

[$lambda](http://docs.jasonette.com/actions/#lambda) is a special purpose action whose sole purpose is to trigger another action. Unlike other actions which carry out some task, it only functions as a mediator that

1. Executes another action
2. Waits for it to return
3. Resumes and starts executing the next action with the return value

The `$lambda` action takes two arguments as its `options`:

1. `name`: The name of the function to trigger
2. `options`: An options object to pass to the triggering action.


Let's take a look at an example usage of `$lambda`:

{% raw %}
```
{
  "fetch": {
    "type": "$lambda",
    "options": {
      "name": "btoa",
      "options": {
        "guid": "{{$cache.guid}}"
      }
    },
    "success": {
      "type": "$network.request",
      "options": {
        "url": "https://.....",
        "data": {
          "guid": "{{$jason.hashed}}"
        }
      },
      "success": {
        "type": "$render"
      }
    }
  }
}
```
{% endraw %}

In this example,

1. We invoke an action called `btoa` (which we will come back to in the next section) using `$lambda`.
2. Then the `$lambda` action waits until the `btoa` action completes its task and returns.
3. Finally when that happens, the `$lambda` action's `success` callback gets executed.
4. Note that the success action is a [$network.request](http://docs.jasonette.com/actions/#networkrequest) action that uses the return value from `btoa` in the form of the variable `$jason`.

<br>

## $return

`$return` is actually not a single action but a category of actions. There are two:

1. [$return.success](http://docs.jasonette.com/actions/#returnsuccess) : Used for returning values on success. This will backtrack to the current action's caller action and execute its `success` callback.
2. [$return.error](http://docs.jasonette.com/actions/#returnerror) : Used for returning an error. This will backtrack to the current action's caller action and execute its `error` callback.

There are two ways of returning--**with return value** and **without return value**

- **Without return value:** If the action doesn't need to return any value, simply doing `"type": "$return.success"` is enough to return the control back to the caller action.
- **With return value:** However if you wish to send a return value back to the caller action, you will need to set the `options`.

For example, when you `$return.success` this way:

{% raw %}
```
{
  "myname": {
    "type": "$return.success",
    "options": {
      "firstname": "Bart",
      "lastname": "Simpson"
    }
  }
}
```
{% endraw %}

You will be able to access the `options` object as `$jason` in the caller action's `success` callback. Here's an example:

{% raw %}
```
{
  "type": "$lambda",
  "options": {
    "name": "myname"
  },
  "success": {
    "type": "$util.toast",
    "options": {
      "text": "My name is {{$jason.firstname}} {{$jason.lastname}}"
    }
  }
}
```
{% endraw %}

Notice how the [$util.toast](http://docs.jasonette.com/actions/#utiltoast) is accessing the `$jason.firstname` and `$jason.lastname` values after the `myname` action returns. 

<br>

Circling back to our `btoa` action, here's what it looks like when we extract the `btoa` action out as a standalone function. All it does is compute the hash and return. (It's basically a manual implementation of [the native btoa function](https://developer.mozilla.org/en-US/docs/Web/API/WindowBase64/Base64_encoding_and_decoding).

{% raw %}
```
{
  "btoa": {
    "type": "$return.success",
    "options": {
      "hashed": "{{var str=$jason.guid; var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='; for ( var block, charCode, idx = 0, map = chars, output = ''; str.charAt(idx | 0) || (map = '=', idx % 1); output += map.charAt(63 & block >> 8 - idx % 1 * 8)) { charCode = str.charCodeAt(idx += 3/4); if (charCode > 0xFF) { throw new InvalidCharacterError('btoa failed'); } block = block << 8 | charCode; } return output;}}"
    }
  }
}
```
{% endraw %}

Notice that the function uses `var str=$jason.guid;` (previously it was `var str=$cache.guid;`).

`$jason` is the argument passed in from the caller action, which means it only exists within this local scope. The function doesn't use global variables like `$cache` anymore.

<br>

## Simplifying $lambda with 'trigger'
`$lambda` actions can be a bit verbose, so there's a syntactic sugar for calling `$lambda` actions.

Instead of using the `$lambda` action directly, you can use the `trigger` keyword to shorten it down.

Instead of the following `$lambda` action:

```
<Action> ::= {
  "type": "$lambda",
  "options": {
    "name": <Action Name>,
    "options": <Arguments object>
  },
  "success": <Action>,
  "error": <Action>
}
```

We can use the `trigger` notation like this:

```
<Action> ::= {
  "trigger": <Action Name>,
  "options": <Arguments object>,
  "success": <Action>,
  "error": <Action>
}
```



For example, instead of this:

{% raw %}
```
{
  "type": "$lambda",
  "options": {
    "name": "some_action",
    "options": {
      "key1": "value1",
      "key2": "value2"
    }
  },
  "success": {
    "type": "$render"
  },
  "error": {
    "type": "$render"
  }
}
```
{% endraw %}

You can use: 

{% raw %}
```
{
  "trigger": "some_action",
  "options": {
    "key1": "value1",
    "key2": "value2"
  },
  "success": {
    "type": "$render"
  },
  "error": {
    "type": "$render"
  }
}
```
{% endraw %}

<br>

# Stay Tuned for Part 2 and 3

If you read this far, you're either thinking:

1. "This is the awesomest thing since Jasonette!" (probably like 5% of you)
2. or, "Yeah cool story bro, now you can do some hipster functional stuff, so what?" (the rest 95%)

I think those of you who have already written long lines of JSON code may immediately get the benefit since it directly deals with your pain point. But even if you're in the group #2, don't feel bad!

Because this is the first piece of the puzzle towards introducing **total modularity** to Jasonette, and I have two more posts coming up where I will talk about how all this fits into the picture.

Stay tuned for the next one very soon.

---

