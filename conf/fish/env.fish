# flutter
set -x PUB_HOSTED_URL https://pub.flutter-io.cn
set -x FLUTTER_STORAGE_BASE_URL https://storage.flutter-io.cn
if command -q chromium
    set -gx CHROME_EXECUTABLE (command -v chromium)
end

# go
set -gx GOPATH "$HOME/go"
fish_add_path "$GOPATH/bin"
