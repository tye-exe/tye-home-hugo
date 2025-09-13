+++
date = '2025-09-11T13:09:46+01:00'
draft = false
title = 'Programming Languages'
+++

Messing around with computers (also known as coding) is what i ~love~ ~enjoy~ tolerate? I'm joking, it's my favorite thing! I have been coding since i figured out how to install [Python](https://www.python.org/) back when i was but a child and have never looked back. Over my years of staring at the computer screen, i have sank hours upon hours into Python and [Java](https://dev.java/learn/), but the two languages that i enjoy fighting with/programming in the most are [Rust](https://www.rust-lang.org/) and [Nix](https://nixos.org/), both of which i adore for different reasons.

### Rust (and Java)

Rust, is there anything new for me to say about it? I'm not really sure, as i will just end up echoing about the memory safety and performance as everyone else does. However, i can add my own tidbit to the table.

Before discovering rust, and yes i will say discover, i primarily used Java. Java has its quirks and odd moments, as all languages do, but the parts that annoyed me the most about Java is the fact the null exists and that runtime errors do not have to be declared in the function signature. The former is a nightmare when trying to work with data that is returned from any functions that do not mention that they might return null. The latter annoys me when i'm trying to find out how and where code can fail, so i can handle it gracefully.

Rust's answer to null is just removing it, null does not exist in Rust. A choice for which i am grateful, as i do not have to deal with "The Billion Dollar Mistake" that null has been labeled. For errors, Rust handles them beautifully, integerating them into the type system. Alas, `panic!()` does exist in Rust, but some errors are much too tedious to be dealt with constantly (looking at you out of memory errors).

At the end of the day, Java is still a language that i spent a lot of time in and that i still hold fondly. Maybe one day i will pick it up again when it is the best solution to a problem that i am facing.

### Nix

I'm quite sure that Nix is far less popular than Rust, which is admittedly deserved, as Nix still has not quite reached the stage where it is "easy" to pick up (mainly due to the documentation). However, it is easy for me to look past this for the most important thing it provides: **Reproducibility**.

Being able to fully recreate any environment and configuration on any machine at any time is a form of a super power. Similar to [Docker](https://www.docker.com/) it prevents the whole "it works on my machine!" issue that so commonly comes up by defining the entire environment so it can be recreated. This is one of the primary reasons why Nixpkgs has the largest and most up to date collection of packages out of any package manager, which is also a big reason why i stick with Nix. The ability to see software and temporarily download it, just to mess around, and then having it be cleaned up after is so freeing. I love it.

Going back to the **Reproducibility**, Nix has convinced my brain that it is working spending time on configuring tools such as Git and [Helix](https://helix-editor.com/) (my IDE) to my exact liking is worth it, because the settings are stored centerally in one placed and shared across all of my devices. It takes time to get everything set up the way i like it, but now that i have i'm always able to work how i want, without ever having to worry about trying to synchronise all of my settings (or trying to remember that one obscure setting that i changed years ago and is essential).

* * *

Partings Traveler
=================

I have enjoyed having you around, stay safe out there on the interwebs!
