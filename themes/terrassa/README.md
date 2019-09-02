# Terrassa - Hugo Theme

Terrassa is a simple, fast and responsive theme for Hugo with a strong focus on accessibility made from scratch.

![Hugo Terrassa theme screenshot](https://github.com/danielkvist/hugo-terrassa-theme/blob/master/images/screenshot.png)

## Features

- Coherent responsive design.
- Consistent design throughout the entire site.
- Classic navigation menu in large screen sizes.
- Hamburger menu in mobile devices.
- Focus on accessibility.
- Customizable call to action on the home page.
- Contact form.
- Ready for blogging.

## Some things that will be added in the future

- A better hamburger menu.
- Service Workers.
- Easier ways to customize fonts and colors.
- Support for comments.

## Installation

To install Terrassa run the followings command inside your Hugo site:

```bash
$ mkdir themes
$ cd themes
$ git clone https://github.com/danielkvist/hugo-terrassa-theme.git terrassa
```

Or

```bash
$ mkdir themes
$ cd themes
$ git submodule add https://github.com/danielkvist/hugo-terrassa-theme.git terrassa
```

> You can also download the last release [here](https://github.com/danielkvist/hugo-terrassa-theme/releases).

Back to your Hugo site directory open the *config.toml* file and add or change the following line:

```toml
theme = "terrassa"
```

## Configuration

> You can find an example of the final configuration [here](https://github.com/danielkvist/hugo-terrassa-theme/blob/master/exampleSite/config.toml).

### Basic

```toml
baseurl = "/"           # The base URL of your Hugo site
title = "titlehere"     # The title of your Hugo site
author = "authorhere"   # The author name
googleAnalytics = ""    # Your Google Analytics tracking ID
enableRobotsTXT = true
language = "en-US"
paginate = 7            # The numbers of posts per page
theme = "terrassa"      # Your Hugo theme
```

There's a lot more information about the basic configuration of an Hugo site [here](https://gohugo.io/getting-started/configuration/).

### Description, favicon and logo params

```toml
[params]
    description = "" # Description for the meta description tag
    favicon = ""     # Relative URL for your favicon
    logo = ""        # Absolute URL for your logo
```

### Hero

```toml
[params.hero]
    textColor = "" # Empty for default color
```

### Call To Action

```toml
[params.cta] # Call To Action 
    show = true
    cta = "Contact"  # Text message of the CTA
    link = "contact" # Relative URL
```

### Separators between Home sections

```toml
[params.separator]
    show = false
```

### Contact information

```toml
[params.contact]
    email = ""
    phone = ""
    skype = ""
    address = ""
```

### Social Networks

```toml
[params.social]
    twitter = ""
    facebook = ""
    github = ""
    gitlab = ""
    codepen = ""
    instagram = ""
    pinterest = ""
    youtube = ""
    linkedin = ""
    weibo = ""
    mastodon = ""
    tumblr = ""
    flickr = ""
    "500px" = ""
```

> Icons for social networks depend on Font Awesome.

### Font Awesome

```toml
[params.fa]
    version = ""    # Font Awesome version
    integrity = ""  # Font Awesome integrity for the Font Awesome script
```

### Copyright message

```toml
[params.copy]
    message = ""
```

### Agreements

```toml
[params.agreement]
    message = ""    # You can use HTML tags
```

### Posts

```toml
[params.posts]
    showAuthor = true
    showDate = true
    showTags = true
    dateFormat = "Monday, Jan, 2006"
```

### Form

```toml
[params.form]
    netlify = true # Only if you are using Netlify
    action = ""
    method = ""
    inputNameName = ""
    inputNameLabel = ""
    inputNamePlaceholder = ""
    inputEmailName = ""
    inputEmailLabel = ""
    inputEmailPlaceholder = ""
    inputMsgName = ""
    inputMsgLabel = ""
    inputMsgLength = 750
    inputSubmitValue = ""
```

### Privacy

```toml
[privacy]
    [privacy.googleAnalytics]
        anonymizeIP = true
        disable = false
        respectDoNotTrack = true
        useSessionStorage = false
    [privacy.instagram]
        disable = false
        simple = false
    [privacy.twitter]
        disable = false
        enableDNT = true
        simple = false
    [privacy.vimeo]
        disable = false
        simple = false
    [privacy.youtube]
        disable = false
        privacyEnhanced = true
```

To learn more about privacy configuration check the [official documentation](https://gohugo.io/about/hugo-and-gdpr/).

### Custom CSS

To add custom CSS you have to create a folder called ```assets``` in the root of your project. Then, create another folder called ```css``` inside ```assets```. And finally, a file called ```custom.css``` inside ```css``` with your styles.

```bash
$ mkdir -p ./assets/css/
```

## Archetypes

Terrassa includes three base archetypes:
* *default*: for content such as blogs posts.
* *section*: for the sections on your Home page.
* *page*: for pages like the About page.

So be careful. Creating a new site with Hugo also creates a default archetype that replaces the one provided by Terrassa.

### Home and Single pages

To create your home page run the following command inside your Hugo site:

```bash
$ hugo new _index.md -k page
```

Or to create another page:

```bash
$ hugo new example.md -k page
```

You'll get something like this:

```markdown
---
title: ""
description: ""
images: []
draft: true
menu: main
weight: 0
---
```

Some properties are used as follows:
* *title*: is the name that will be displayed in the menu. In the rest of the single pages the main title of the content.
* *description*: in the case of the home page the description is not shown. In the rest of the single pages it is shown as a subtitle.
* *images*: in the case of the home page the first image is used as the background image for the hero and to share on social networks (with [Twitter Cards](https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards.html) and [Facebook Graph](https://developers.facebook.com/docs/graph-api/)). In every other page or post is used only for share on social networks.
* *weight*: sets the order of the items in the menu.

## Home page Sections

To create a new section in your Home page follow the next steps:

```bash
$ hugo new sections/example.md -k section
```

You'll come across something like this:

```markdown
---
title: "Example"
description: ""
draft: true
weight: 0
---
```

The *title* is used as the title of your new section and the content is the body. At this moment the *description* is not used for anything.

The *weight* defines the order in case of having more than one section.

### Blog or List pages

To create a Blog or a page with a similar structure follow these steps:

```bash
$ hugo new posts/_index.md -k page
```

> In this case it is only necessary to set, if wanted, the *title* and the *weight* in the *_index.md*.

To add a new posts run the following command:

```bash
$ hugo new posts/bad-example.md
```

Inside this file you'll find something like this:

```markdown
---
title: "Bad example"
description: ""
date: 2018-12-27T21:09:45+01:00
publishDate: 2018-12-27T21:09:45+01:00
author: "John Doe"
images: []
draft: true
tags: []
---
```
The *title* and *description* are used as the main title and subtitle respectively.

> You can find more information about each parameter in the [official documentation](https://gohugo.io/content-management/front-matter/).

Then, the corresponding section will show a list of cards with the *title*, the *date*, a *summary of the content* (truncated to 480 words) and a list of *tags* if any.

![Hugo Terrassa theme Blog section screenshot](https://github.com/danielkvist/hugo-terrassa-theme/blob/master/images/blog-screenshot.png)

### Contact

For the contact page follow these instructions:

```bash
$ hugo new contact/_index.md -k page
```

The *title* and *description* will be used as the main title and subtitle respectively with a contact form. The rest of the options are defined in the [config.toml](https://github.com/danielkvist/hugo-terrassa-theme/blob/master/exampleSite/config.toml).