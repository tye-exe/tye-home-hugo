+++
date = '2025-09-16T11:04:59+01:00'
draft = false
title = 'Hugo Website Development'
+++

This post assumes that you know what [Hugo](https://gohugo.io/) is, but if you are overly familiar, you'll be bored.

# Preamble
I've recently rewritten my website (for at least the third time).
- The first time was in [Rust](https://www.rust-lang.org/) using [egui](https://github.com/emilk/egui) with the [WebAssembly](https://webassembly.org/) target. This turned out to be a bad idea due to non-universal support and the file size, which was about 1.8MB compressed (argh!).
- The second time was using pure [HTML](https://developer.mozilla.org/en-US/docs/Web/HTML) and [CSS](https://developer.mozilla.org/en-US/docs/Web/CSS), which certainly resulted in a smaller file size of 16.10kB (compressed), but was rather a pain to expand, as HTML can be a tad time consuming to read and write raw.
- The third time is this time!

# Meat And Bones
My primary reasons for choosing Hugo over other site generators is the [Markdown](https://www.markdownguide.org/getting-started/) support and lack of [Javascript](https://en.wikipedia.org/wiki/JavaScript). The Markdown makes adding new content easy, which will (hopefully) prevent me from wanting to add more content but procrastinating as "making a function HTML page is work". For Javascript, my avoidance mainly boils down to trying to see if I can make a "modern" website without it

## Templates

Hugo works by taking the content in Markdown files and inserting bits and pieces into pre-made HTML files, known as [templates](https://gohugo.io/templates/introduction/), with some additional processing before outputting a finial HTML file for each page on the website. This "additional processing" includes capabilities such as loops, text manipulation, and image processing. All of this makes it easy to setup a "base" template (the intended way of using Hugo), which gets automatically updated by Hugo whenever new content is added to the website.

The Hugo [getting started guide](https://gohugo.io/getting-started/quick-start/) recommends using pre-made templates, which is probably a good idea, but since templates control how your site looks and works, I decided to take the hard route and make my own. To give a brief overview of the mistakes I made when making my own.

### Base Template
Make use of the [Base template](https://gohugo.io/templates/types/#base) feature, as this enables other templates to insert their content into pre-defined places, such as the \<body\> tag.

{{< collapsible title="What Not To Do">}}
`./layouts/baseof.html`
```html
<!DOCTYPE html>
<html>
  <head>
    <!-- Generic Head settings -->
  </head>
  <body>
    <nav>
      <!-- Custom navbar HTML -->
    </nav>
    <h1>My Website!</h1>
    <p>I hope you enjoy!</p>
  </body>
</html>
```

`./layouts/page.html`
```html
<!DOCTYPE html>
<html>
  <head>
    <!-- Same generic Head settings -->
  </head>
  <body>
    <nav>
      <!-- Custom navbar HTML -->
    </nav>
    <h1>{{- .Title -}}</h1>
    {{- .Content -}}
  </body>
</html>
```
{{< /collapsible >}}

{{< collapsible title="What To Do Instead">}}
`./layouts/baseof.html`
```html
<!DOCTYPE html>
<html>
  <head>
    <!-- Generic Head settings -->
  </head>
  <body>
    <nav>
      <!-- Custom navbar HTML -->
    </nav>
    {{- block "main" . -}}
    {{- end -}}
  </body>
</html>
```

`./layouts/page.html`
```html
{{- define "main" -}}
<h1>{{- .Title -}}</h1>
{{- .Content -}}
{{- end -}}
```
{{< /collapsible >}}

Both of the layouts will render the exact same, but the latter has no HTML duplication, which makes it alot easier to maintain.

### Define Blocks
As stated in the Hugo docs, "It must include **at least** one [define](https://gohugo.io/functions/go-template/define/) action". In other words, you can have multiple define blocks in the base template.

One particular use case *that drained a decent chunk of my day to figure out* is including an additional define block in the \<head\> section of the base template to include CSS files that only applied to a single page.

{{< collapsible title="For example" >}}
`./layouts/baseof.html`
```html
<!DOCTYPE html>
<html>
  <head>
    <!-- Generic Head settings -->
    {{- block "head" . -}}
    {{- end -}}
  </head>
  <body>
    <nav>
      <!-- Custom navbar HTML -->
    </nav>
    {{- block "main" . -}}
    {{- end -}}
  </body>
</html>
```

`./layouts/page.html`
```html
{{- define "main" -}}
<h1>{{- .Title -}}</h1>
{{- .Content -}}
{{- end -}}

{{- define "head" -}}
{{- $sheet:= resources.Get "page.css" -}
<link rel="stylesheet" href="{{ $sheet.Permalink }}">
{{- end -}}
```
{{< /collapsible >}}

I came to this realisation after trying to use "\[Page|Site|hugo\].Store", which failed miserably.

## Syntax
Hugo syntax is a tad unique, as someone who hasn't used [Go templates](https://blog.gopheracademy.com/advent-2017/using-go-templates/) before, which is not helped by no dedicated [Language Server](https://langserver.org/) existing. It can lead to a bit of a frustrating experience for the first few hours, with dozens of tabs being opened to try and figure out what syntax exists and how to use it.

Building upon this, the documentation for Hugo is good with tons of documentation available on [gohugo.io](https://gohugo.io/documentation/). However, it still is a new "language" that a developer needs to learn, which will take a few hours before the basics are understood.


## Closing Thoughts
My overall experience with Hugo has been good (hence the existence of this website), despite it taking a few days for me to figure out the basics. As someone who has a good understanding of HTML, it was okay enough to start using Hugo as a layer on-top of that. If you're proficient in Javascript, then a Javascript framework will most likely be a better alternative.

Most of the foot-guns that come up can be solved via a quick internet search. However, there were still a few questions that took me some sleuthing to track down.
