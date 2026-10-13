// drmtext: draw text on the panel through raw DRM/KMS (dumb buffer + SETCRTC),
// the same path Android's recovery UI uses. No libdrm, static binary.
// usage: drmtext [-s scale] [file]   (text from file or stdin; stays running to keep the fb)
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <drm/drm.h>
#include <drm/drm_mode.h>

#include "font8x16.h"

#define FG 0x00e0e0e0
#define BG 0x00101820

static int fd;

static int xioctl(unsigned long req, void *arg)
{
	int r;
	do {
		r = ioctl(fd, req, arg);
	} while (r < 0 && (errno == EINTR || errno == EAGAIN));
	return r;
}

static void die(const char *what)
{
	fprintf(stderr, "drmtext: %s: %s\n", what, strerror(errno));
	exit(1);
}

int main(int argc, char **argv)
{
	int scale = 3, i;
	const char *path = NULL;

	for (i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-s") && i + 1 < argc)
			scale = atoi(argv[++i]);
		else
			path = argv[i];
	}
	FILE *in = path ? fopen(path, "r") : stdin;
	if (!in)
		die("open text");

	fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
	if (fd < 0)
		die("open /dev/dri/card0");
	xioctl(DRM_IOCTL_SET_MASTER, 0);

	struct drm_mode_card_res res = { 0 };
	if (xioctl(DRM_IOCTL_MODE_GETRESOURCES, &res))
		die("GETRESOURCES");
	uint32_t *conns = calloc(res.count_connectors + 1, 4);
	uint32_t *crtcs = calloc(res.count_crtcs + 1, 4);
	uint32_t *encs = calloc(res.count_encoders + 1, 4);
	uint32_t *fbs = calloc(res.count_fbs + 1, 4);
	res.connector_id_ptr = (uintptr_t)conns;
	res.crtc_id_ptr = (uintptr_t)crtcs;
	res.encoder_id_ptr = (uintptr_t)encs;
	res.fb_id_ptr = (uintptr_t)fbs;
	if (xioctl(DRM_IOCTL_MODE_GETRESOURCES, &res))
		die("GETRESOURCES 2");

	struct drm_mode_modeinfo mode;
	uint32_t conn_id = 0, enc_id = 0, crtc_id = 0;
	int found = 0;
	for (i = 0; i < (int)res.count_connectors && !found; i++) {
		struct drm_mode_get_connector c = { .connector_id = conns[i] };
		if (xioctl(DRM_IOCTL_MODE_GETCONNECTOR, &c))
			continue;
		fprintf(stderr, "connector %u type %u status %u modes %u\n", c.connector_id,
			c.connector_type, c.connection, c.count_modes);
		if (c.connection != 1 || !c.count_modes)
			continue;
		struct drm_mode_modeinfo *modes = calloc(c.count_modes, sizeof(*modes));
		uint32_t *cencs = calloc(c.count_encoders + 1, 4);
		struct drm_mode_get_connector c2 = { .connector_id = conns[i] };
		c2.count_modes = c.count_modes;
		c2.modes_ptr = (uintptr_t)modes;
		c2.count_encoders = c.count_encoders;
		c2.encoders_ptr = (uintptr_t)cencs;
		if (xioctl(DRM_IOCTL_MODE_GETCONNECTOR, &c2))
			continue;
		int m = 0, j;
		for (j = 0; j < (int)c2.count_modes; j++)
			if (modes[j].type & DRM_MODE_TYPE_PREFERRED) {
				m = j;
				break;
			}
		mode = modes[m];
		conn_id = c2.connector_id;
		enc_id = c2.encoder_id ? c2.encoder_id : (c2.count_encoders ? cencs[0] : 0);
		found = 1;
	}
	if (!found) {
		fprintf(stderr, "drmtext: no connected connector with modes\n");
		return 1;
	}

	struct drm_mode_get_encoder e = { .encoder_id = enc_id };
	if (xioctl(DRM_IOCTL_MODE_GETENCODER, &e))
		die("GETENCODER");
	crtc_id = e.crtc_id;
	for (i = 0; !crtc_id && i < (int)res.count_crtcs; i++)
		if (e.possible_crtcs & (1u << i))
			crtc_id = crtcs[i];
	fprintf(stderr, "mode %s %ux%u@%u conn %u enc %u crtc %u\n", mode.name, mode.hdisplay,
		mode.vdisplay, mode.vrefresh, conn_id, enc_id, crtc_id);

	struct drm_mode_create_dumb cd = { .width = mode.hdisplay, .height = mode.vdisplay, .bpp = 32 };
	if (xioctl(DRM_IOCTL_MODE_CREATE_DUMB, &cd))
		die("CREATE_DUMB");
	struct drm_mode_fb_cmd fb = { .width = cd.width, .height = cd.height, .pitch = cd.pitch,
				      .bpp = 32, .depth = 24, .handle = cd.handle };
	if (xioctl(DRM_IOCTL_MODE_ADDFB, &fb))
		die("ADDFB");
	struct drm_mode_map_dumb md = { .handle = cd.handle };
	if (xioctl(DRM_IOCTL_MODE_MAP_DUMB, &md))
		die("MAP_DUMB");
	uint32_t *px = mmap(0, cd.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, md.offset);
	if (px == MAP_FAILED)
		die("mmap");

	uint32_t W = cd.width, H = cd.height, stride = cd.pitch / 4, x, y;
	for (y = 0; y < H; y++)
		for (x = 0; x < W; x++)
			px[y * stride + x] = BG;

	// margins keep text clear of the rounded corners and the camera cutout
	uint32_t mx = 40, my = 140, cw = 8 * scale, ch = 16 * scale;
	uint32_t cols = (W - 2 * mx) / cw, col = 0, row = 0;
	int c;
	while ((c = fgetc(in)) != EOF) {
		if (c == '\n' || col >= cols) {
			col = 0;
			row++;
			if (c == '\n')
				continue;
		}
		if (my + (row + 1) * ch > H - 100)
			break;
		const unsigned char *g = font8x16[(unsigned char)c];
		uint32_t gx, gy;
		for (gy = 0; gy < ch; gy++)
			for (gx = 0; gx < cw; gx++)
				if (g[gy / scale] & (0x80 >> (gx / scale)))
					px[(my + row * ch + gy) * stride + mx + col * cw + gx] = FG;
		col++;
	}

	struct drm_mode_crtc sc = { .crtc_id = crtc_id, .fb_id = fb.fb_id, .set_connectors_ptr = (uintptr_t)&conn_id,
				    .count_connectors = 1, .mode = mode, .mode_valid = 1 };
	if (xioctl(DRM_IOCTL_MODE_SETCRTC, &sc))
		die("SETCRTC");
	fprintf(stderr, "drmtext: frame set\n");

	// a command-mode panel only latches on commit: flip to the same fb a few times
	for (i = 0; i < 3; i++) {
		struct drm_mode_crtc_page_flip pf = { .crtc_id = crtc_id, .fb_id = fb.fb_id };
		xioctl(DRM_IOCTL_MODE_PAGE_FLIP, &pf);
		usleep(100000);
	}
	// dropping the fd would tear the framebuffer down, so stay around
	for (;;)
		pause();
}
