
eval "$(/opt/homebrew/bin/brew shellenv)"

export JAVA_HOME=/Applications/Android\ Studio.app/Contents/jre/Contents/Home/
export ANDROID_SDK_ROOT="/Users/jame/Library/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'

php() {
	docker run --rm \
		-v "$(pwd)":/opt \
		-w /opt \
		-it \
		laravelsail/php81-composer:latest \
		bash -c "php $*";
}

laravel() {
	docker run --rm \
                -v "$(pwd)":/opt \
                -w /opt \
		-it \
                laravelsail/php81-composer:latest \
                bash -c "laravel $*"
}
composer() {
        docker run --rm \
                -v "$(pwd)":/opt \
                -w /opt \
                -it \
                laravelsail/php81-composer:latest \
                bash -c "composer $*"
}
artserve() {
	docker run --rm \
                -v "$(pwd)":/opt \
                -w /opt \
		-p 8000:8000 \
		-it \
                laravelsail/php81-composer:latest \
                bash -c "php artisan serve --host 0.0.0.0";
}
