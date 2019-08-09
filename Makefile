CONFIG_FILES=src/_config.yml,${CURDIR}/_config.yml
DIST=dist

chalk:
	test -d $(CHALK_DIR) || mkdir vendor && git clone $(CHALK_GITHUB) $(CHALK_DIR)

define chalk_link_template
ln -s ${CHALK_DIR}/$(1) $(2)/$(1);
endef
chalk-link:
	$(foreach file, $(CHALK_FILES), $(call chalk_link_template,$(file),src))
	$(foreach file, $(CHALK_INCLUDES), $(call chalk_link_template,$(file),src))

define chalk_unlink_template
test -e $(2)/$(1) && rm $(2)/$(1);
endef
chalk-unlink:
	$(foreach file, $(CHALK_FILES), $(call chalk_unlink_template,$(file),src))
	$(foreach file, $(CHALK_INCLUDES), $(call chalk_unlink_template,$(file),src))

define uglifycss
mkdir -p $(addprefix ./$(DIST)/,$(dir $1));
csso --input $(1) --output $(1);
endef
uglify: build
	$(foreach file, $(shell find ./src/_site -name '*.css'), $(call uglifycss,$(file)))

define compress_file
mkdir -p $(addprefix ./$(DIST)/,$(dir $1));
gzip -c $(1) > $(addprefix $(DIST)/,$(basename $1))$(suffix $1);
endef
compress: build
	$(foreach file, $(shell find ./src/_site -name '*.html' \
		-or -name '*.css' \
		-or -name '*.js' \
		-or -name '*.xml' \
		-or -name '*.eot' \
		-or -name '*.ttf' \
		-or -name '*.ico' \
		-or -name '*.svg'), $(call compress_file,$(file)))

define cp_file
mkdir -p $(addprefix ./$(DIST)/,$(dir $1));
cp $(1) $(addprefix $(DIST)/,$(basename $1))$(suffix $1);
endef
standard: build
	$(foreach file, $(shell find ./src/_site -name '*.woff' -or -name '*.woff2' -or -name 'robots.txt'), $(call cp_file,$(file)))

src/_assets/yarn: src/package.json
	docker build --tag blog-assets .
	docker run -it -v $(PWD):/app -w /app blog-assets \
		/bin/bash -c 'yarn install --modules-folder ./src/_assets/yarn'

src/_site: src/_assets/yarn $(shell find ./src -name '*' -not -path '*/_site*')
	docker build --tag blog-build .
	docker run -it -v $(PWD):/app -w /app blog-build \
		/bin/bash -c 'jekyll build --config src/_config.yml,_config.yml'

build:
	bundle exec jekyll build --config ${CONFIG_FILES}

S3_BUCKET:=s3://s3.kieranbamforth.me/apps/blog

deploy: uglify compress standard
	aws s3 rm $(S3_BUCKET) --recursive
	# HTML
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.html" \
		--content-type "text/html;charset=UTF-8" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# JS
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.js" \
		--content-type "text/javascript" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# CSS
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.css" \
		--content-type "text/css" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# XML
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.xml" \
		--content-type "text/xml" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# EOT
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.eot" \
		--content-type "application/vnd.ms-fontobject" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# TTF
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.ttf" \
		--content-type "application/octet-stream" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# WOFF
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.woff" \
		--content-type "font/woff" \
		--cache-control "Cache-Control: max-age=3600"
	# WOFF2
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.woff2" \
		--content-type "font/woff2" \
		--cache-control "Cache-Control: max-age=3600"
	# SVG
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.svg" \
		--content-type "image/svg+xml" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# ICO
	aws s3 cp $(DIST)/src/_site $(S3_BUCKET) --recursive \
		--exclude "*" \
		--include "*.ico" \
		--content-type "image/x-icon" \
		--cache-control "Cache-Control: max-age=3600" \
		--content-encoding "gzip"
	# Robots.txt
	aws s3 cp $(DIST)/src/_site/robots.txt $(S3_BUCKET) --content-type "text/plain"

serve:
	bundle exec jekyll serve --drafts --config ${CONFIG_FILES}

setup:
	test -e ./Gemfile || ln -s $(CHALK_DIR)/Gemfile ./Gemfile
	bundle install
	test -e ./package.json || ln -s $(CHALK_DIR)/package.json ./package.json
	yarn install --modules-folder ./src/_assets/yarn
