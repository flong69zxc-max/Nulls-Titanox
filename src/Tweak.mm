#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <libgen.h>
#import <string.h>
#import <stdio.h>
#import <stdarg.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "fishhook.h"

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
static ssize_t (*orig_sendto)(int, const void *, size_t, int, const struct sockaddr *, socklen_t) = NULL;
static ssize_t (*orig_recvfrom)(int, void *, size_t, int, struct sockaddr *, socklen_t *) = NULL;

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
    return orig_connect(sockfd, addr, addrlen);
}

static ssize_t my_sendto(int sockfd, const void *buf, size_t len, int flags,
                         const struct sockaddr *dest_addr, socklen_t addrlen) {
    if (dest_addr) log_addr("[SENDTO]", dest_addr);
    if (len >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("  -> msg_id=0x%04x len=%zu", msg_id, len);
    }
    return orig_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}

static ssize_t my_recvfrom(int sockfd, void *buf, size_t len, int flags,
                           struct sockaddr *src_addr, socklen_t *addrlen) {
    ssize_t r = orig_recvfrom(sockfd, buf, len, flags, src_addr, addrlen);
    if (r > 0 && src_addr) log_addr("[RECVFROM]", src_addr);
    if (r >= 7 && buf) {
        const uint8_t *b = (const uint8_t *)buf;
        uint16_t msg_id = (b[0] << 8) | b[1];
        TaleLog("  <- msg_id=0x%04x len=%zd", msg_id, r);
    }
    return r;
}

static void install_hooks(void) {
    TaleLog("[NetLog] === install ===");
    struct rebinding rb[] = {
        {"connect",  (void *)my_connect,  (void **)&orig_connect},
        {"sendto",   (void *)my_sendto,   (void **)&orig_sendto},
        {"recvfrom", (void *)my_recvfrom, (void **)&orig_recvfrom}
    };
    int r = rebind_symbols(rb, 3);
    TaleLog("[NetLog] rebind_symbols = %d", r);
    TaleLog("[NetLog] connect=%p sendto=%p recvfrom=%p", orig_connect, orig_sendto, orig_recvfrom);
    TaleLog("[NetLog] === install done ===");
}

__attribute__((constructor))
static void tweak_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        TaleLog("[NetLog] init");
        install_hooks();
        TaleLog("[NetLog] === done ===");
    });
}