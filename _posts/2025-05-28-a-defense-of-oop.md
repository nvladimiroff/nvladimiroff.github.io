---
layout: post
title: A defense of object-orientated programming
---

Object-orientated programming has fallen out of fashion. Some newer programming languages, like Go and Rust, don't support it at all. Even in languages that do support it, some developers prefer to pretend it doesn't exist. The momentum is clear: developers think OOP was an oops.

But I think this is the wrong direction for our craft to go. OOP is still a powerful tool that can be used to write great code.

## What even is OOP anyway?

Object-orientated programming is the programming style of combining data and behavior into units called _objects_, and hiding all of that behind _message-passing_. Some languages map message-passing to functions calls (like Java or C#) and others take message-passing a bit more literally (like Ruby or Objective-C).

I think this is a fantastic style of programming because it lets you make powerful abstractions about the relationship between your data and behavior, and its relationship to the outside world.

## Data, behavior, and the outside world

Your data has behavior whether you want it to or not.

For example, if you're writing code for a video streaming platform, videos can often only played by people in the right country. If you just pass around a video struct without any behavior, you've made that relationship mandatory to understand if you want to use that struct. You've increased the mental burden you put on people who use your code.

In an object-orientated style, data and behavior can be hidden behind message-passing. You can make it so the outside world doesn't need to know that a video is region-locked. It just needs to know that videos respond to the `play` message. In doing this you've created a very powerful abstraction.

Creating abstractions that hide some details--like the region-locking rule--and emphasize others--like that videos can be played--is the essence of OOP.

Objects aren't the only unit of abstraction you'll have in your codebase, but it's a very useful one when you have data that has behavior associated with it.

## Where it goes wrong

If this is such a great approach, why are some people moving away from it? People are hesitant about OOP because OOP is a sharp knife--powerful, but easily misused.

An abstraction that fits well can make code a joy to work with. An abstraction that fits poorly can be a nightmare; think of Java's infamous `AbstractBeanFactory`s or deep pits of inheritance. OOP makes both good and bad abstractions more powerful.

But people shouldn't stop using knives. They should be taught how to use them without slicing their fingers.
