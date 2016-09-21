TARGET         := nixy
BINARY         := bin/$(TARGET)
DEFAULT_TARGET := build
SOURCEDIR=.
SOURCES        := $(shell find $(SOURCEDIR) -name '*.go')
VERSION        := $(shell cat .goxc.json | jq -r '.PackageVersion')

$(BINARY): $(SOURCES)
	GOARCH=amd64 GOOS=linux go build -a \
		-ldflags '-w -linkmode external -extldflags "-static"' \
		-o bin/$(TARGET) .

docker: $(BINARY)
	docker build -t dylanmei/$(TARGET) .

publish: docker
	docker push dylanmei/$(TARGET):latest
	docker tag dylanmei/$(TARGET) dylanmei/$(TARGET):$(VERSION)
	docker push dylanmei/$(TARGET):$(VERSION)
