#!/bin/bash

set -e

OUTPUT_DIR="output"
mkdir -p "$OUTPUT_DIR"

FORMAT="${1:-all}"

check_deps() {
    if ! command -v pandoc &> /dev/null; then
        echo "错误: pandoc 未安装"
        echo "安装: sudo apt install pandoc (Ubuntu)"
        echo "或: brew install pandoc (macOS)"
        exit 1
    fi
}

build_pdf() {
    local input="$1"
    echo "生成 PDF..."
    pandoc "$input" \
        -o "$OUTPUT_DIR/book.pdf" \
        --pdf-engine=xelatex \
        -V CJKmainfont="Noto Sans CJK SC" \
        -V geometry:margin=1in \
        --toc \
        --toc-depth=2
    echo "  $OUTPUT_DIR/book.pdf"
}

build_epub() {
    local input="$1"
    echo "生成 EPUB..."
    pandoc "$input" \
        -o "$OUTPUT_DIR/book.epub" \
        --toc \
        --toc-depth=2 \
        --metadata title="如何设计内核"
    echo "  $OUTPUT_DIR/book.epub"
}

build_html() {
    local input="$1"
    echo "生成 HTML..."
    pandoc "$input" \
        -o "$OUTPUT_DIR/book.html" \
        --toc \
        --toc-depth=2 \
        --standalone \
        --metadata title="如何设计内核" \
        -V theme=readable
    echo "  $OUTPUT_DIR/book.html"
}

main() {
    check_deps
    local input="$1"
    if [ -z "$input" ] || [ ! -f "$input" ]; then
        echo "用法: $0 <book.md> [pdf|epub|html|all]"
        exit 1
    fi

    case "$FORMAT" in
        pdf) build_pdf "$input" ;;
        epub) build_epub "$input" ;;
        html) build_html "$input" ;;
        all)
            build_pdf "$input"
            build_epub "$input"
            build_html "$input"
            ;;
        *)
            echo "未知格式: $FORMAT"
            echo "支持: pdf, epub, html, all"
            exit 1
            ;;
    esac

    echo "编译完成。输出目录: $OUTPUT_DIR/"
}

main "$@"