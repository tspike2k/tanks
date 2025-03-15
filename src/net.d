/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

// TODO: Better logging!

import memory;
import logging;

enum Socket_Status : uint {
    Closed     = 0,
    Opened     = 1,
    Listening  = 2,
    Connecting = 3,
    Connected  = 4,
}

enum{
    Socket_Flag_Broadcast = (1 << 0),
}

enum{
    Socket_Event_Readable = (1 << 0),
    Socket_Event_Writable = (1 << 1),
}

version(linux){
    import core.sys.posix.sys.types;
    import core.sys.posix.sys.socket;
    import core.sys.posix.netinet.in_;
    import core.sys.posix.netinet.tcp;
    import core.sys.posix.netdb;
    import core.sys.posix.arpa.inet;
    import core.sys.posix.fcntl;
    import core.sys.posix.unistd;
    import core.sys.posix.poll;
    import core.sys.linux.errno;
    import core.stdc.string : strerror;

    enum SOCK_NONBLOCK = 2048; // For some reason, this isn't define by the standard D bindings.

    struct Socket{
        Socket_Status status;
        uint          events;
        uint          flags;

        private:
        int fd;
        addrinfo* address_info;
    }

    bool open_socket(Socket* sock, String address, String port, uint flags){
        assert(sock.status == Socket_Status.Closed);
        assert(address.length != 0 || address.ptr == null);

        bool is_host = address.length == 0;
        sock.events = 0;

        auto hints = zero_type!addrinfo;
        hints.ai_family   = AF_UNSPEC;
        hints.ai_socktype = SOCK_DGRAM;
        if(is_host)
            hints.ai_flags = AI_PASSIVE;

        bool success = false;
        addrinfo* info;
        if(getaddrinfo(address.ptr, port.ptr, &hints, &info) == 0){
            assert(info); // TODO: Is this always non-null when getaddrinfo returns 0?

            // TODO: We should probably loop through each res node looking for the best fit.
            // However, I'm not sure how we'd know what would be best.
            sock.fd = socket(info.ai_family, info.ai_socktype | SOCK_NONBLOCK, info.ai_protocol);
            if(sock.fd != -1){
                success           = true;
                sock.status       = Socket_Status.Opened;
                sock.flags        = flags;
                sock.address_info = info;
            }
            else{
                //log_error("Unable to open socket at address %s:%s\n", address, port);
                log_error("Unable to open socket at address ");
                log(address);
                log(":");
                log(port);
                log("\n");
            }
        }
        else{
            //log_error("Unable to get host address information: %s\n", gai_strerror(e));
            log_error("Unable to get address info for socket.\n");
        }

        if(!success){
            close_socket(sock);
        }

        return success;
    }

    bool socket_listen(Socket* sock){
        assert(sock.status == Socket_Status.Opened);

        // Allow the host to reclaim socket number quickly when reconnecting.
        int value = 1;
        if(setsockopt(sock.fd, SOL_SOCKET, SO_REUSEADDR, &value, value.sizeof) == -1){
            log_error("Unable to set socket to reuse addresses.\n");
        }

        bool success = false;
        // Associate the address information filled out above with the socket file descriptor opened earlier.
        addrinfo *info = sock.address_info;
        if(bind(sock.fd, info.ai_addr, info.ai_addrlen) == 0){
            success = true;
            sock.status = Socket_Status.Listening;

            // 5 is the typical maximum size of the backlog queue
            // TODO: Is that even true? Can we get the maximum like in Windows?
            listen(sock.fd, 5); // TODO: Can listen fail?
            log("Created host socket\n"); // TODO: Print host IP address and port number.
        }
        else{
            log_error("Unable to bind socket fd. Aborting.\n");
            close_socket(sock);
        }
        return success;
    }

    bool socket_connect(Socket* sock){
        assert(sock.status == Socket_Status.Opened || sock.status == Socket_Status.Connecting);

        if(sock.status == Socket_Status.Opened){
            if(sock.flags & Socket_Flag_Broadcast){
                int value = 1;
                if(setsockopt(sock.fd, SOL_SOCKET, SO_BROADCAST, &value, value.sizeof)){
                    log_error("Unable to configure socket for broadcasting.\n");
                }
            }
        }

        // Async use of connect adapted from here:
        // https://rigtorp.se/sockets/
        bool failed = false;
        auto info = sock.address_info;
        int e = connect(sock.fd, info.ai_addr, info.ai_addrlen);
        if(e == 0){
            sock.status = Socket_Status.Connected;
            log("Socket connected!\n");
        }
        else{
            assert(e == -1);
            if(errno == EINPROGRESS || errno == EINTR){
                sock.status = Socket_Status.Connecting;
            }
            else{
                log_error("Socket unable to connect to address.\n");
                failed = true;
                close_socket(sock);
            }
        }


        return !failed;
    }

    void close_socket(Socket* sock){
        if(sock.status != Socket_Status.Closed){
            assert(sock.fd != -1);
            close(sock.fd);
            sock.fd     = -1;
            sock.status = Socket_Status.Closed;
            sock.events = 0;
        }
    }

    void sockets_update(Socket[] sockets, Allocator* allocator){
        auto scratch = allocator.scratch;
        push_frame(scratch);
        scope(exit) pop_frame(scratch);

        auto poll_fds     = alloc_array!pollfd(scratch, sockets.length);
        auto poll_sources = alloc_array!(Socket*)(scratch, sockets.length);
        uint poll_fds_count;

        foreach(ref socket; sockets){
            if(socket.status == Socket_Status.Listening
            || socket.status == Socket_Status.Connected){
                auto index = poll_fds_count++;
                auto entry = &poll_fds[index];
                entry.fd = socket.fd;
                entry.revents = POLLIN|POLLOUT;
                poll_sources[index] = &socket;
            }
            else if(socket.status == Socket_Status.Connecting){
                socket_connect(&socket);
            }
        }

        if(poll_fds_count > 0){
            poll(&poll_fds[0], poll_fds_count, 0);

            foreach(i, ref entry; poll_fds[0 .. poll_fds_count]){
                auto socket = poll_sources[i];
                socket.events = 0;

                auto events = entry.revents;
                if(events & POLLIN){
                    socket.events |= Socket_Event_Readable;
                }
                if(events & POLLOUT){
                    socket.events |= Socket_Event_Writable;
                }
            }
        }
    }

    uint socket_read(Socket *sock, void* buffer, uint buffer_length){
        // TODO: More robust reading
        uint result = 0;
        if(sock.status != Socket_Status.Closed){
            assert(sock.events & Socket_Event_Readable);

            auto bytes_read = recv(sock.fd, buffer, buffer_length, 0);
            if(bytes_read > 0){
                result = cast(uint)bytes_read;
            }
            else if(bytes_read == 0){
                // TODO: 0 means EOF. Is it safe to close the socket?
                log("Socket read EOF. Closing socket\n");
                close_socket(sock);
            }
            else{
                if(errno == ECONNRESET){
                    // We should only get ECONNRESET if the connection is broken. In that case,
                    // the only thing I know to do is close the connection.
                    //
                    // TODO: Is there some way of refreshing the connection?
                    close_socket(sock);
                }
                // TODO: We're ignoring EGAIN since it means the pipe is empty when doing a
                // non-blocking read (I think). We should figure out why this happens. Is this
                // expected, or am I using poll wrong?
                //
                // Sources:
                // https://medium.com/@cpuguy83/non-blocking-i-o-in-go-bc4651e3ac8d
                else if(errno != EAGAIN){
                    //log_error("(%d) Socket read error: %s\n", errno, strerror(errno));
                    log_error("Socket read error: \n");
                }
            }
        }

        return result;
    }

    void socket_write(Socket *sock, const(void)* buffer, size_t buffer_length){
        // TODO: More robust writing
        auto bytes_written = send(sock.fd, buffer, cast(uint)buffer_length, 0);
        if(bytes_written < 0){
            auto msg_raw = strerror(errno);
            auto msg = msg_raw[0 .. strlen(msg_raw)];
            log_error("Write error: ");
            log(msg);
            log("\n");
        }
        else if(buffer_length != cast(uint)bytes_written){
            log_error("Short write.\n");
        }
    }
}
