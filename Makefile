# make post name=my-first-post
post:
	hugo new posts/$(name)/index.en.md

server:
	hugo server -D --disableFastRender & \
	open http://localhost:1313


