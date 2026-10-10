/* OvaSpawn's C part (PLAN.md, "The rulebook viewer"): starting a program
   detached, in a session of its own; running one and reading its
   standard output; and the process facts the module needs. Every program
   is given as an argument vector, n NUL-terminated strings packed one
   after another in buf, and run with execvp: no shell, so nothing is
   quoted. Each function returns 0 or an errno, unless it says otherwise. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

/* argv for buf's n strings, NULL-terminated, malloc'd; NULL if out of
   memory. */
static char **unpack(const char *buf, int32_t n) {
  char **argv = malloc((size_t)(n + 1) * sizeof *argv);
  if (argv == NULL) return NULL;
  for (int32_t i = 0; i < n; i++) { argv[i] = (char *)buf; buf += strlen(buf) + 1; }
  argv[n] = NULL;
  return argv;
}

/* Reads exactly sizeof *v bytes into v; 1 if it did, 0 at end of file. */
static int read_int(int fd, int32_t *v) {
  ssize_t r;
  do r = read(fd, v, sizeof *v); while (r < 0 && errno == EINTR);
  return r == (ssize_t)sizeof *v;
}

static void write_int(int fd, int32_t v) {
  ssize_t r;
  do r = write(fd, &v, sizeof v); while (r < 0 && errno == EINTR);
}

/* Waits for pid, retrying on EINTR; its wait status in *status. */
static void wait_for(pid_t pid, int *status) {
  while (waitpid(pid, status, 0) < 0 && errno == EINTR) {}
}

/* Starts buf's program detached: a child makes a new session (setsid)
   and forks the program, then exits at once, so the program is init's,
   never a zombie of ours, and a hangup of our terminal doesn't reach it.
   Its standard input, output and error are /dev/null. *pid is the
   program's. A failed exec comes back as its errno, through a
   close-on-exec pipe: end of file on it means the exec succeeded. */
int32_t ova_spawn_detached(const char *buf, int32_t n, int32_t *pid) {
  int err = 0, pids[2], errs[2], status;
  int32_t got;
  char **argv;
  pid_t child;

  *pid = 0;
  if (n < 1) return EINVAL;
  if ((argv = unpack(buf, n)) == NULL) return ENOMEM;
  if (pipe2(pids, O_CLOEXEC) != 0) { err = errno; free(argv); return err; }
  if (pipe2(errs, O_CLOEXEC) != 0) {
    err = errno; close(pids[0]); close(pids[1]); free(argv); return err;
  }
  child = fork();
  if (child < 0) {
    err = errno;
    close(pids[0]); close(pids[1]); close(errs[0]); close(errs[1]); free(argv);
    return err;
  }
  if (child == 0) {
    pid_t g;
    close(pids[0]); close(errs[0]);
    setsid();
    g = fork();
    if (g < 0) { write_int(errs[1], errno); _exit(1); }
    if (g > 0) { write_int(pids[1], (int32_t)g); _exit(0); }
    close(pids[1]);
    int nul = open("/dev/null", O_RDWR);
    if (nul >= 0) { dup2(nul, 0); dup2(nul, 1); dup2(nul, 2); if (nul > 2) close(nul); }
    execvp(argv[0], argv);
    write_int(errs[1], errno);
    _exit(127);
  }
  close(pids[1]); close(errs[1]); free(argv);
  wait_for(child, &status);
  if (!read_int(pids[0], &got)) got = 0;
  if (read_int(errs[0], &err) == 0) err = 0;
  close(pids[0]); close(errs[0]);
  if (err == 0) *pid = got;
  return err;
}

/* Starts buf's program with its standard output on a pipe, whose read
   end is *fd, and its standard input and error on /dev/null; *pid is
   the program's. Read *fd with ova_spawn_read, then call
   ova_spawn_finish. A failed exec is returned as its errno, the program
   already waited for. */
int32_t ova_spawn_capture(const char *buf, int32_t n, int32_t *fd, int32_t *pid) {
  int err = 0, outs[2], errs[2], status;
  char **argv;
  pid_t child;

  *fd = -1; *pid = 0;
  if (n < 1) return EINVAL;
  if ((argv = unpack(buf, n)) == NULL) return ENOMEM;
  if (pipe2(outs, O_CLOEXEC) != 0) { err = errno; free(argv); return err; }
  if (pipe2(errs, O_CLOEXEC) != 0) {
    err = errno; close(outs[0]); close(outs[1]); free(argv); return err;
  }
  child = fork();
  if (child < 0) {
    err = errno;
    close(outs[0]); close(outs[1]); close(errs[0]); close(errs[1]); free(argv);
    return err;
  }
  if (child == 0) {
    int nul = open("/dev/null", O_RDWR);
    dup2(outs[1], 1);
    if (nul >= 0) { dup2(nul, 0); dup2(nul, 2); if (nul > 2) close(nul); }
    execvp(argv[0], argv);
    write_int(errs[1], errno);
    _exit(127);
  }
  close(outs[1]); close(errs[1]); free(argv);
  if (read_int(errs[0], &err) == 0) err = 0;
  close(errs[0]);
  if (err != 0) { close(outs[0]); wait_for(child, &status); return err; }
  *fd = outs[0]; *pid = child;
  return 0;
}

/* Up to len bytes from fd into buf: how many, 0 at end of file, or
   -errno. */
int64_t ova_spawn_read(int32_t fd, char *buf, int64_t len) {
  ssize_t r;
  do r = read(fd, buf, (size_t)len); while (r < 0 && errno == EINTR);
  return r < 0 ? -(int64_t)errno : (int64_t)r;
}

/* Closes fd and waits for pid: its exit status, or -1 if a signal ended
   it. */
int32_t ova_spawn_finish(int32_t fd, int32_t pid) {
  int status = 0;
  close(fd);
  wait_for(pid, &status);
  return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

/* When pid started, in clock ticks since boot (/proc/PID/stat's 22nd
   field), which tells a process from a later one given the same pid;
   -1 if there is no such process. */
int64_t ova_spawn_start_time(int32_t pid) {
  char path[64], line[1024], *p;
  long long start = -1;
  FILE *f;
  int i;

  snprintf(path, sizeof path, "/proc/%d/stat", (int)pid);
  if ((f = fopen(path, "r")) == NULL) return -1;
  if (fgets(line, sizeof line, f) == NULL) { fclose(f); return -1; }
  fclose(f);
  /* The name, field 2, is in parentheses and may hold blanks: count
     from the last ')'. Field 3 follows it; field 22 is 19 more on. */
  if ((p = strrchr(line, ')')) == NULL) return -1;
  p++;
  for (i = 0; i < 19 && p != NULL; i++) p = strchr(p + 1, ' ');
  if (p == NULL || sscanf(p, "%lld", &start) != 1) return -1;
  return (int64_t)start;
}

/* Sends SIGTERM to pid if it is still the process that started at
   start; ESRCH if it isn't, or is gone. */
int32_t ova_spawn_terminate(int32_t pid, int64_t start) {
  if (pid <= 0 || start < 0 || ova_spawn_start_time(pid) != start) return ESRCH;
  return kill(pid, SIGTERM) == 0 ? 0 : errno;
}

/* 1 if name, run with execvp, would be found and could be run: a name
   with a '/' as it is, any other in a directory of PATH. */
int32_t ova_spawn_on_path(const char *name) {
  const char *path, *dir, *end;
  char full[4096];

  if (name[0] == 0) return 0;
  if (strchr(name, '/') != NULL) return access(name, X_OK) == 0;
  path = getenv("PATH");
  if (path == NULL) path = "/usr/local/bin:/usr/bin:/bin";
  for (dir = path; ; dir = end + 1) {
    end = strchrnul(dir, ':');
    /* An empty entry is the current directory. */
    if (end == dir) snprintf(full, sizeof full, "./%s", name);
    else snprintf(full, sizeof full, "%.*s/%s", (int)(end - dir), dir, name);
    if (access(full, X_OK) == 0) return 1;
    if (*end == 0) return 0;
  }
}

/* err's text, as strerror gives it, in buf (len bytes). */
void ova_spawn_error_text(int32_t err, char *buf, int32_t len) {
  snprintf(buf, (size_t)len, "%s", strerror(err));
}

/* pid's session; -1 if there is no such process. */
int32_t ova_spawn_session(int32_t pid) {
  return (int32_t)getsid(pid);
}
