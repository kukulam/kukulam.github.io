# make post name=my-first-post
post:
	hugo new posts/$(name)/index.en.md

server:
	open http://localhost:1313
	hugo server --disableFastRender
