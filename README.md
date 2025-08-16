Phrack E-book Generator
=======================

This is a fork of Albinowax's [phrackgen script](https://www.skeletonscribe.net/2011/12/phrack-ebook.html). 

I fixed some regexes, removed the `LWP::Simple` and `Archive::Extract`dependencies, and download online content with cURL and extract with Tar from a Bash script instead: 

```
$ ./perl.sh
```
