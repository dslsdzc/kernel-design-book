// build-wiki.c — 扫描 wiki 概念页 → 生成系统聚合页 + SUMMARY.md
// 编译: gcc -O3 -o build-wiki build-wiki.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#define MAX_SYSTEMS 16
#define MAX_LINE 4096
#define MAX_ITEMS 1024

typedef struct { char name[64]; char *items[MAX_ITEMS]; int n; } SystemPage;

typedef struct { char *items[MAX_ITEMS]; int n; } ConceptList;

char *sys_names[] = {"seL4","Linux","HIC","QNX","MINIX","CHERI","L4",NULL};
SystemPage systems[MAX_SYSTEMS];
ConceptList concepts[4];
char *cat_names[] = {"permission","scheduling","structure","resource",NULL};
char *cat_labels[] = {"权限模型","调度模型","结构模型","资源模型",NULL};

void trim(char *s) { char *p=s+strlen(s)-1; while(p>=s&&(*p=='\n'||*p=='\r'||*p==' '))*p--=0; }

void scan_file(const char *path, const char *rel) {
    FILE *f = fopen(path, "r");
    if (!f) return;
    char line[MAX_LINE];
    char title[256] = {0};
    int in_h2 = 0; char h2_text[256];

    while (fgets(line, sizeof(line), f)) {
        trim(line);

        // 提取 H1 标题
        if (line[0] == '#' && line[1] == ' ') {
            strncpy(title, line+2, sizeof(title)-1);
            continue;
        }

        // 匹配所有 ## / ### / #### 等标题（跳过头部的 #）
        char *hdr = line;
        while (*hdr == '#') hdr++;
        if (hdr - line >= 2 && *hdr == ' ') {
            strncpy(h2_text, hdr + 1, sizeof(h2_text)-1);
            in_h2 = 1;
            for (int s = 0; sys_names[s]; s++) {
                if (strstr(h2_text, sys_names[s])) {
                    // 生成锚点：与 mdBook/pulldown-cmark 一致
                    // 规则：大写→小写，空格/特殊字符→-，保留中文字符
                    char anchor[256]; int ai=0;
                    for (int ci=0; h2_text[ci] && ai<250; ci++) {
                        unsigned char c = h2_text[ci];
                        if (c >= 'A' && c <= 'Z') anchor[ai++] = c - 'A' + 'a';
                        else if (c >= 'a' && c <= 'z') anchor[ai++] = c;
                        else if (c >= '0' && c <= '9') anchor[ai++] = c;
                        else if (c >= 0x80) anchor[ai++] = c; // 保留中文
                        else if (c == ' ' || c == '-' || c == '_') anchor[ai++] = '-';
                    }
                    anchor[ai] = 0;
                    char link[512], buf[MAX_LINE];
                    snprintf(link, sizeof(link), "../%s#%s", rel, anchor);
                    snprintf(buf, sizeof(buf), "  - [%s](%s)", h2_text, link);
                    systems[s].items[systems[s].n++] = strdup(buf);
                    break;
                }
            }
        }
    }
    fclose(f);

    // 归类到概念列表
    if (strlen(title) == 0) return;
    for (int c = 0; cat_names[c]; c++) {
        if (strncmp(rel, cat_names[c], strlen(cat_names[c])) == 0) {
            char buf[MAX_LINE];
            snprintf(buf, sizeof(buf), "  - [%s](%s)", title, rel);
            concepts[c].items[concepts[c].n++] = strdup(buf);
            break;
        }
    }
}

void scan_dir(const char *dir, const char *prefix) {
    DIR *d = opendir(dir);
    if (!d) return;
    struct dirent *de;
    while ((de = readdir(d))) {
        if (de->d_name[0] == '.') continue;
        char path[MAX_LINE], rel[MAX_LINE];
        snprintf(path, sizeof(path), "%s/%s", dir, de->d_name);
        snprintf(rel, sizeof(rel), "%s/%s", prefix, de->d_name);

        struct stat st;
        stat(path, &st);
        if (S_ISDIR(st.st_mode)) {
            scan_dir(path, rel);
        } else if (strstr(de->d_name, ".md")) {
            scan_file(path, rel);
        }
    }
    closedir(d);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "用法: build-wiki <wiki_src_dir>\n"); return 1; }
    const char *wiki_src = argv[1];

    // 初始化
    for (int i = 0; sys_names[i]; i++) strncpy(systems[i].name, sys_names[i], 63);

    // 1. 扫描所有概念页
    for (int c = 0; cat_names[c]; c++) {
        char path[MAX_LINE];
        snprintf(path, sizeof(path), "%s/%s", wiki_src, cat_names[c]);
        scan_dir(path, cat_names[c]);
    }

    // 2. 生成系统页
    char sys_dir[MAX_LINE];
    snprintf(sys_dir, sizeof(sys_dir), "%s/systems", wiki_src);
    mkdir(sys_dir, 0755);
    for (int s = 0; sys_names[s]; s++) {
        char spath[MAX_LINE];
        snprintf(spath, sizeof(spath), "%s/%s.md", sys_dir, sys_names[s]);
        FILE *f = fopen(spath, "w");
        if (!f) continue;
        fprintf(f, "# %s\n\n该页面自动聚合了各概念页中提及 %s 的内容。\n\n", sys_names[s], sys_names[s]);
        if (systems[s].n > 0) {
            fprintf(f, "## 相关内容\n\n");
            for (int i = 0; i < systems[s].n; i++)
                fprintf(f, "%s\n", systems[s].items[i]);
        } else {
            fprintf(f, "暂未收录相关内容。\n");
        }
        fclose(f);
    }

    // 3. 生成 SUMMARY.md
    char spath[MAX_LINE];
    snprintf(spath, sizeof(spath), "%s/SUMMARY.md", wiki_src);
    FILE *f = fopen(spath, "w");
    fprintf(f, "# 内核设计 Wiki\n\n[关于此 Wiki](index.md)\n\n---\n");
    for (int c = 0; cat_names[c]; c++) {
        fprintf(f, "- [%s](%s/README.md)\n", cat_labels[c], cat_names[c]);
        for (int i = 0; i < concepts[c].n; i++)
            fprintf(f, "%s\n", concepts[c].items[i]);
    }
    fprintf(f, "\n---\n\n## 按系统浏览\n");
    for (int s = 0; sys_names[s]; s++)
        fprintf(f, "- [%s](systems/%s.md)\n", sys_names[s], sys_names[s]);
    fprintf(f, "\n---\n\n- [贡献指南](CONTRIBUTING.md)\n");
    fclose(f);

    printf("[OK] %d 系统页 + %d 概念页\n", 7,
        concepts[0].n+concepts[1].n+concepts[2].n+concepts[3].n);
    return 0;
}
