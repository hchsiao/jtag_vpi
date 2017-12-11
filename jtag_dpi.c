/*
 * TCP/IP controlled VPI JTAG Interface.
 * Based on Julius Baxter's work on jp_vpi.c
 *
 * Copyright (C) 2012 Franck Jullien, <franck.jullien@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation  and/or other materials provided with the distribution.
 * 3. Neither the names of the copyright holders nor the names of any
 *    contributors may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <arpa/inet.h>

#include <svdpi.h>

#define RSP_SERVER_PORT	22222

// NOTICE!!
// Should be consist with jtag driver in openocd and SystemVerilog
#define	XFERT_MAX_SIZE	512

const char * cmd_to_string[] = {"CMD_RESET",
				"CMD_TMS_SEQ",
				"CMD_SCAN_CHAIN"};

struct vpi_cmd {
	int cmd;
	unsigned char buffer_out[XFERT_MAX_SIZE];
	unsigned char buffer_in[XFERT_MAX_SIZE];
	int length;
	int nb_bits;
};

int listenfd = 0;
int connfd = 0;

int init_jtag_server(int port)
{
	struct sockaddr_in serv_addr;
	int flags;

	printf("Listening on port %d\n", port);

	listenfd = socket(AF_INET, SOCK_STREAM, 0);
	memset(&serv_addr, '0', sizeof(serv_addr));

	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	serv_addr.sin_port = htons(port);

	bind(listenfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));

	listen(listenfd, 10);

	printf("Waiting for client connection...");
	connfd = accept(listenfd, (struct sockaddr*)NULL, NULL);
	printf("ok\n");

	flags = fcntl(listenfd, F_GETFL, 0);
	fcntl(listenfd, F_SETFL, flags | O_NONBLOCK);

	return 0;
}

// See if there's anything on the FIFO for us

int check_for_command(struct vpi_cmd* cmd)
{
	int nb;
  int ercd = 0;

	// Get the command from TCP server
	if(!connfd)
	  ercd = init_jtag_server(RSP_SERVER_PORT);
  if(0 != ercd)
    return ercd;

	nb = read(connfd, cmd, sizeof(struct vpi_cmd));

	if (((nb < 0) && (errno == EAGAIN)) || (nb == 0)) {
		// Nothing in the fifo this time, let's return
		return 0;
	} else {
		if (nb < 0) {
			// some sort of error
			perror("check_for_command");
      return 1;
		}
	}
}

int send_result_to_server(const struct vpi_cmd* cmd)
{
	ssize_t n;
  int ercd = 0;

	n = write(connfd, cmd, sizeof(struct vpi_cmd));
	if (n < (ssize_t)sizeof(struct vpi_cmd)) {
		vpi_printf("jtag_vpi: ERROR: error during write to server\n");
    return n;
  }
  return ercd;
}

void sim_finish_callback(void)
{
	if(connfd)
		printf("Closing RSP server\n");
	close(connfd);
	close(listenfd);
}

