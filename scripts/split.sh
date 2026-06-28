#!/bin/bash

INPUT="$1"
if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
    echo "用法: $0 <book.md>"
    exit 1
fi

# 提取部分标题时去掉“第X部分”前缀，只保留“总起：内核需要干嘛”部分
awk '
BEGIN {
    # 初始化状态
    part_dir = ""
    ch_file = ""
}

# 匹配部分标题行
/^#+ 第[0-9]+部分 / {
    # 提取完整标题，如 "第1部分 总起：内核需要干嘛"
    # 然后把它变成目录名
    part_title = $0
    # 去掉开头的 # 和空格
    gsub(/^#+ /, "", part_title)
    # 替换冒号和空格为合法目录字符
    gsub(/[：:]/, "-", part_title)
    gsub(/ /, "_", part_title)
    part_dir = part_title
    # 创建目录
    system("mkdir -p \"" part_dir "\"")
    print "创建目录: " part_dir
    # 关闭当前章节（如果有）
    ch_file = ""
    next
}

# 匹配章节标题
/^## 第[0-9]+章 / {
    # 提取章节号
    ch_num = ""
    if (match($0, /第([0-9]+)章/, arr)) {
        ch_num = arr[1]
    }
    # 提取章节标题
    ch_title = substr($0, index($0, "章") + 2)
    # 安全文件名
    safe_title = ch_title
    gsub(/[ /:：]/, "-", safe_title)
    gsub(/--*/, "-", safe_title)
    filename = sprintf("%02d_%s.md", ch_num, safe_title)
    ch_file = part_dir "/" filename
    print "创建章节: " ch_file
    # 写入章节标题（去掉"##"前缀）
    print "# 第" ch_num "章 " ch_title > ch_file
    next
}

# 普通行：追加到当前章节文件
ch_file != "" {
    print >> ch_file
}
' "$INPUT"

echo "拆分完成！"