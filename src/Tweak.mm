#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <libgen.h>
#import <string.h>
#import <stdio.h>
#import <stdarg.h>
#import <unistd.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

extern "C" {
    struct rebinding {
        const char *name;
        void *replacement;
        void *replaced;
    };
    int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);
}

static FILE *g_logf = NULL;

static void TaleLogOpen(void) {
    if (g_logf) return;
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"netlog.log"];
    g_logf = fopen(path.UTF8String, "w");
}

static void TaleLog(const char *fmt, ...) {
    if (!g_logf) TaleLogOpen();
    if (!g_logf) return;
    va_list ap; va_start(ap, fmt); vfprintf(g_logf, fmt, ap); fputc('\n', g_logf); va_end(ap); fflush(g_logf);
}

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    NSLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static int (*orig_connect)(int, const struct sockaddr *, socklen_t) = NULL;
static ssize_t (*orig_send)(int, const void *, size_t, int) = NULL;
static ssize_t (*orig_recv)(int, void *, size_t, int) = NULL;
static ssize_t (*orig_sendto)(int, const void *, size_t, int, const struct sockaddr *, socklen_t) = NULL;
static ssize_t (*orig_recvfrom)(int, void *, size_t, int, struct sockaddr *, socklen_t *) = NULL;
static ssize_t (*orig_write)(int, const void *, size_t) = NULL;
static ssize_t (*orig_read)(int, void *, size_t) = NULL;

static void log_addr(const char *fn, const struct sockaddr *addr) {
    if (!addr) return;
    if (addr->sa_family == AF_INET) {
        struct sockaddr_in *sin = (struct sockaddr_in *)addr;
        char ip[INET_ADDRSTRLEN] = {0};
        inet_ntop(AF_INET, &sin->sin_addr, ip, sizeof(ip));
        TaleLog("%s AF_INET %s:%d", fn, ip, ntohs(sin->sin_port));
    } else if (addr->sa_family == AF_INET6) {
        struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)addr;
        char ip[INET6_ADDRSTRLEN] = {0};
        inet_ntop(AF_INET6, &sin6->sin6_addr, ip, sizeof(ip));
        TaleLog("%s AF_INET6 [%s]:%d", fn, ip, ntohs(sin6->sin6_port));
    } else {
        TaleLog("%s family=%d", fn, addr->sa_family);
    }
}

static int my_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    log_addr("[CONNECT]", addr);
    if (orig_connect) return orig_connect(sockfd, addr, addrlen);
    return -1;
}

static ssize_t my_send(int sockfd, const void *buf, size_t len, int flags) {
    if (len >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("[SEND] fd=%d msg_id=0x%04x len=%zu", sockfd, msg_id, len);
    }
    if (orig_send) return orig_send(sockfd, buf, len, flags);
    return -1;
}

static ssize_t my_recv(int sockfd, void *buf, size_t len, int flags) {
    ssize_t r = orig_recv ? orig_recv(sockfd, buf, len, flags) : -1;
    if (r >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("[RECV] fd=%d msg_id=0x%04x len=%zd", sockfd, msg_id, r);
    }
    return r;
}

static ssize_t my_sendto(int sockfd, const void *buf, size_t len, int flags,
                         const struct sockaddr *dest_addr, socklen_t addrlen) {
    if (dest_addr) log_addr("[SENDTO]", dest_addr);
    if (len >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("  -> msg_id=0x%04x len=%zu", msg_id, len);
    }
    if (orig_sendto) return orig_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
    return -1;
}

static ssize_t my_recvfrom(int sockfd, void *buf, size_t len, int flags,
                           struct sockaddr *src_addr, socklen_t *addrlen) {
    ssize_t r = orig_recvfrom ? orig_recvfrom(sockfd, buf, len, flags, src_addr, addrlen) : -1;
    if (r > 0 && src_addr) log_addr("[RECVFROM]", src_addr);
    if (r >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("  <- msg_id=0x%04x len=%zd", msg_id, r);
    }
    return r;
}

static ssize_t my_write(int fd, const void *buf, size_t len) {
    if (len >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("[WRITE] fd=%d msg_id=0x%04x len=%zu", fd, msg_id, len);
    }
    if (orig_write) return orig_write(fd, buf, len);
    return -1;
}

static ssize_t my_read(int fd, void *buf, size_t len) {
    ssize_t r = orig_read ? orig_read(fd, buf, len) : -1;
    if (r >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("[READ] fd=%d msg_id=0x%04x len=%zd", fd, msg_id, r);
    }
    return r;
}

static void install_hooks(void) {
    TaleLog("[NetLog] === install ===");
    struct rebinding rb[] = {
        {"connect",  (void *)my_connect,  (void **)&orig_connect},
        {"send",     (void *)my_send,     (void **)&orig_send},
        {"recv",     (void *)my_recv,     (void **)&orig_recv},
        {"sendto",   (void *)my_sendto,   (void **)&orig_sendto},
        {"recvfrom", (void *)my_recvfrom, (void **)&orig_recvfrom},
        {"write",    (void *)my_write,    (void **)&orig_write},
        {"read",     (void *)my_read,     (void **)&orig_read}
    };
    int r = rebind_symbols(rb, 7);
    TaleLog("[NetLog] rebind_symbols = %d", r);
    TaleLog("[NetLog] connect=%p",  orig_connect);
    TaleLog("[NetLog] send=%p",     orig_send);
    TaleLog("[NetLog] recv=%p",     orig_recv);
    TaleLog("[NetLog] sendto=%p",   orig_sendto);
    TaleLog("[NetLog] recvfrom=%p", orig_recvfrom);
    TaleLog("[NetLog] write=%p",    orig_write);
    TaleLog("[NetLog] read=%p",     orig_read);
    TaleLog("[NetLog] === install done ===");
}

__attribute__((constructor))
static void tweak_init(void) {
    TaleLog("[NetLog] init");
    install_hooks();
    TaleLog("[NetLog] === done ===");
}