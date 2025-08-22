#!/usr/bin/env bash


case $1 in
"status")
    STATUS=`fcitx5-remote`
    case $STATUS in
    "0")
        echo "窱"
        ;;
    "1")
        echo ""
        ;;
    "2")
        echo "גּ"
        ;;
    esac
    ;;
"toggle")
    fcitx5-remote -t
    ;;
esac

