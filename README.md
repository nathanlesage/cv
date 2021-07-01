# Curriculum Vitae LaTeX Template

> I use this CV template to create my own CV, and so can you!

![CV.png](CV.png)

While I never especially liked Microsoft Word, I was especially annoyed by it after many years of exclusively writing in Markdown when I had to use it because I had no CV template set up but was under the pressure of a deadline. Several times throughout the process of having to write a CV from scratch in Word the thought did occur to me to murder something.

This is why I decided that a much better method for my own piece of mind would be to finally take the challenge upon me to create my very own CV template, which you can find in this repository.

[Take me right to the instructions](#how-to-use)!

## Why Yet Another CV Template?

You might ask why I saw it necessary to create yet another CV template, when the internet is littered with them? Good question! There are a few reasons why I chose this road:

- **Pandoc-Compatible**: Most templates are designed to work with LaTeX directly, but I personally prefer Pandoc, since Markdown (and the accompanying data structures) are just much cleaner than raw TeX source
- **Single-File**: Even those templates that can work with Pandoc still have quite a lot of files coming with them, and I prefer (at least for simple projects such as a CV) a single-file template
- **Few Dependencies**: We’re talking about a CV here, one of whose main aims is to be readable and minimalistic. Many templates I’ve seen had me install quite a few additional packages. This template tries to be modest in this regard.
- **Straight-forward data structures**: A CV is basically a PDF-version of a lot of data on your own life. Whenever something changes, do you really want to add the whole boilerplate code just for that one new employment? By making use of Pandoc’s YAML frontmatters, we can do all of this with much less code.
- **Learning**: The least-important reason from your perspective is that I like to try out stuff. This CV prove a good opportunity to freshen up my knowledge of TeX, Pandoc templates, and the whole process of crafting a final PDF file.

But now you certainly want to get started, right? So let’s see how!

## How To Use

This repository basically contains four files:

* README.md: This file
* CV.md: The Markdown source code that also includes all of the data
* cv.template.tex: The actual CV template
* CV.pdf: A rendered version of the CV, built using Zettlr
* CV.png: The first page of my CV for demonstration purposes (not necessarily up to date)

What you’ll need personally is basically just the CV.md and the cv.template.tex files.

### Adding Your Own Data

After downloading the files you want to edit the file, since it obviously includes my data, not yours. I have attempted to structure it as simple as possible. There are basically two types of data that you can use:

- General metadata (name, occupation, address, and some template stuff)
- Sections with the actual data

Some general notes: Most fields can contain Markdown code so that you can, e.g., emphasise certain portions of text. But try to be sparse with this (remember: CVs are clean, not street carnival). Additionally, a lot of the properties allow multiple lines of text. In order to do so, provide a list of strings. They will be delimited by `\newline` in the output. Of course, you can just add a single string in the property if you don’t want multiple lines. Lastly, if you don’t need something, you can basically leave off the property and the template should still compile.

Lastly, I should mention that you can add some sections that do not fit the list-like style of the rest of the CV. I personally use that to add my research interests, but you might add something else. Whatever is the actual contents of your Markdown document (not the YAML frontmatter) will be displayed as-is between the occupation/address/contact header and the horizontal ruler that divides that from the tabular data.

In order to save space, here’s just some YAML code where I commented all possible values that you can use in the frontmatter and how you can use them:

```yaml
# The name is required. It is used as the main heading as well as in a few
# other places.
name: Hendrik Erz
# The accent color allows you to customise the accent colour. It has the format
# r,g,b where each colour component can range from 0.0 to 1.0 (not 0-255!).
accentColor: 0.5,0.0,0.4
# The text color is used wherever accentColor isn't.
textColor: 0.2,0.2,0.2
# The "main" font is what will be used for basically all the regular text.
# You'll get an error if LaTeX cannot find the font on your computer.
mainfont: Roboto
# The "sans" font will be used, e.g., for headings and other non-main-text-body
# text. Based on my own experiences, I strongly suggest you do NOT choose two
# different fonts, and also (since your CV is almost guaranteed never printed)
# a sans-serif font.
sansfont: Roboto
# The occupation is the bold-printed first line above your address.
occupation: PhD Student
# Address is pretty much just a few lines that will be added below occupation.
# This means, if you don't want your address, feel free to add a quote or
# something. Or, leave it out completely!
# Remember: each list item is one line.
address:
  - Institute for Analytical Sociology # Imagine an "\newline" here
  - Linköping University # Same
  - 601 74 Norrköping, Sweden # No newline here.
# "Contact" is also basically just a list of strings which you can omit
# if you don't want to be contacted.
# NOTE: These properties will all be wrapped in "\url{}"!
contact:
  - hendrik.erz@liu.se
  - https://www.hendrik-erz.de/
# Now follows the main portion.
# sections takes a list of -- you guessed it: sections! Each section
# has a title, which will be -- you again guessed it: the title of it.
sections:
  - title: Education
  # A second property is "items". Items is a list of list items.
	items:
        # The "label" will be written in the accent colour to the left.
        # You can also leave off "label" completely and only provide the
        # "text" property. In that case, the text will be correctly aligned
        # with the other texts but has no label. You can make use of this
        # for subsections (see the CV.md for examples).
      - label: Since 2020
        # Text will be in the default text colour on the right.
        # You can also provide a list of strings here (just like with address
        # and contact) and the strings will be written with a "\newline"
        # command.
        text: PhD in Analytical Sociology, Linköping University
      - label: 2017
        text: M.A. in Sociology, University of Bonn
      - label: 2014
        # Make sure to escape strings which contain reserved characters.
        text: "B.A. in History, University of Bonn (minor: Political Science)"
# ... add as many sections with as many items as you like!
```

### But What About My Publications?

That’s a good question. Almost _everybody_ nowadays simply provides a `.bib`-file containing their publications which will just be pushed into the final CV. However, I think that is not the easiest way. The main reason for this is that your CV is not a paper of yours, so the list of publications looks different. After all, your publication list will look suspiciously fishy since there’s one person _always_ involved. So for your CV, different rules than for citing in a paper apply. First, the publications should be sorted by publication date descending. Second, depending on how it would look, you probably wanna leave out the “author” field, since – even though everyone knows these are _your_ publications – your name repeated for thirty items will look weird. And lastly, you may wanna leave out … let’s say, less fortunate texts. With YAML you can simply comment out certain items. Try that with a CSL JSON database or Bib: Much more tricky!

Plus, even though it _is_ quite the effort to get your list of publications in there for the first time, afterwards it’s just about correcting a few things here and there.

> One final note, though! There will certainly be links inside your references. Make sure to surround them with `\\url{}`. The reason is that Pandoc uses slightly different syntax to auto-link these which will look extremely ugly. I’ve configured `\url{}` to look good, but not the Pandoc version. Plus, note the double-backslash. A single is not enough!

### Building

There are two ways of using the template: Either by running Pandoc directly on it, or by using an editor (completely egoistical suggestion: Use [Zettlr](https://github.com/Zettlr/Zettlr) for this!).

With Pandoc, the full command looks like this:

```bash
pandoc CV.md --template=cv.template.tex --pdf-engine=xelatex -o CV.pdf
```

> Note that I’m explicitly selecting the XeLaTeX engine, which is necessary for a few of the packages. If you have a LaTeX distribution installed on your computer, chances are almost certain that XeLaTeX is part of it!

If you want to use Zettlr the simplest way is to load the full folder, open `CV.md`, adapt it to your needs, select the template as the PDF template, and click export whenever you wanna see how it looks! Note that you unfortunately cannot specify the template in the YAML frontmatter itself, so you need to make sure to always comment out the CV template when you’re not working on the CV. Otherwise the results might be … interesting.

## License

Since it wasn’t that much effort and since attribution with CVs is pretty difficult anyways, I hereby license the template file (obviously not my personal data!) using [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). That means: you can just use the template however you like. But please don’t impersonate me in your applications/on your website.

**I’d be pretty happy if you could nevertheless give me a [shoutout on Twitter](https://www.twitter.com/sahiralsaid) if you found that template useful. ❤️**