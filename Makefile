# Makefile for hugo site
.PHONY: dev
dev:
	hugo server

.PHONY: build
build:
	hugo

.PHONY: deploy
deploy: build
	cd public && python3 -m http.server 8000

.PHONY: new-en
new-en:
	if [ -z "$(POST)" ];then echo "Usage: make new-en POST=my-post-name"; exit 1; fi
	# create directory if not exists
	if [ ! -d "content/posts/${POST}" ];then mkdir -p content/posts/${POST}; fi
	# check if the post exists
	if [ -f "content/posts/${POST}.en.md" ];then echo "The post ${POST}.en.md already exists"; exit 1; fi
	hugo new --kind post-en content/posts/${POST}/index.en.md

.PHONY: new-zh
new-zh:
	if [ -z "$(POST)" ];then echo "Usage: make new-zh POST=my-post-name"; exit 1; fi
	# create directory if not exists
	if [ ! -d "content/posts/${POST}" ];then mkdir -p content/posts/${POST}; fi
	# check if the post exists
	if [ -f "content/posts/${POST}.zh-tw.md" ];then echo "The post ${POST}.zh-tw.md already exists"; exit 1; fi
	hugo new --kind post-zh-tw content/posts/${POST}/index.zh-tw.md

.PHONY: new
new: new-en new-zh
