
eval "$(/opt/homebrew/bin/brew shellenv)"

export JAVA_HOME=/Applications/Android\ Studio.app/Contents/jre/Contents/Home/
export ANDROID_SDK_ROOT="/Users/jame/Library/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

php() {
	docker run --rm \
		-v "$(pwd)":/opt \
		-w /opt \
		laravelsail/php81-composer:latest \
		bash -c "php $1"
}
