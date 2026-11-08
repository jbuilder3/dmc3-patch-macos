#ifndef DMC3_ARCHIVE_API_H
#define DMC3_ARCHIVE_API_H

// The macOS SDK exports libarchive but omits its public headers.
// Declarations correspond to libarchive's public read-only APIs.
#include <stdint.h>
#include <sys/types.h>

struct archive;
struct archive_entry;

struct archive *archive_read_new(void);
int archive_read_support_format_zip(struct archive *);
int archive_read_support_format_rar(struct archive *);
int archive_read_support_format_rar5(struct archive *);
int archive_read_open_filename(struct archive *, const char *, size_t);
int archive_read_next_header(struct archive *, struct archive_entry **);
int archive_read_data_skip(struct archive *);
ssize_t archive_read_data(struct archive *, void *, size_t);
int archive_read_free(struct archive *);

const char *archive_entry_pathname_utf8(struct archive_entry *);
const char *archive_entry_hardlink(struct archive_entry *);
const char *archive_entry_symlink(struct archive_entry *);
mode_t archive_entry_filetype(struct archive_entry *);
int archive_entry_is_encrypted(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);

#endif
