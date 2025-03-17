/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

/+
    Note: It is reasonable to assume the maximum size of a UDP payload that won't be
    fragmented during transmission is 508 bytes. That's not too terrible.

    See here for more info:
    https://stackoverflow.com/a/35697810
+/

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
    Socket_Broadcast      = (1 << 0),
    Socket_Reause_Address = (1 << 1),
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

    struct Socket_Address{
        union{
            ushort       sin_family;
            sockaddr_in  ipv4;
            sockaddr_in6 ipv6;
        }
        uint size;
    }

    struct Socket{
        Socket_Status  status;
        uint           events;
        uint           flags;

        private:
        int fd;
    }

    Socket_Address make_socket_address(String address_string, String port){
        bool is_host = address_string.length == 0;

        auto result = zero_type!Socket_Address;
        short port_number = void;
        if(to_int(&port_number, port)){
            result.sin_family = AF_INET;
            result.size = sockaddr_in.sizeof;
            result.ipv4.sin_port = htons(port_number);
            if(is_host){
                result.ipv4.sin_addr.s_addr = INADDR_ANY; // Accept connections from any address
            }
            else{
                //TODO: Error handling
                assert(result.sin_family == AF_INET);
                inet_pton(result.sin_family, address_string.ptr, &result.ipv4.sin_addr);
            }
        }
        else{
            log_error("Unable to convert port '");
            log(port);
            log("' to integer.\n");
        }
        return result;
    }

    bool open_socket(Socket* sock, uint flags){
        assert(sock.status == Socket_Status.Closed);

        bool success = false;
        sock.fd = socket(AF_INET, SOCK_DGRAM | SOCK_NONBLOCK, 0);
        if(sock.fd != -1){
            if(flags & Socket_Broadcast){
                sock.flags |= Socket_Broadcast;
                int value = 1;
                if(setsockopt(sock.fd, SOL_SOCKET, SO_BROADCAST, &value, value.sizeof)){
                    log_error("Unable to configure socket for broadcasting.\n");
                }
            }

            if(flags & Socket_Reause_Address){
                sock.flags |= Socket_Reause_Address;
                int value = 1;
                if(setsockopt(sock.fd, SOL_SOCKET, SO_REUSEADDR, &value, value.sizeof) == -1){
                    log_error("Unable to set socket to reuse addresses.\n");
                }
            }

            sock.status = Socket_Status.Opened;
            success = true;
        }
        else{
            // TODO: Get error string!
            log_error("Unable to open socket: \n");
        }

        return success;
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

    bool is_valid(Socket_Address* address){
        bool result = address.size > 0;
        return result;
    }

    bool bind_socket(Socket* socket, Socket_Address* address){
        assert(socket.status != Socket_Status.Closed);

        bool success = false;
        if(is_valid(address)){
            success = bind(socket.fd, cast(sockaddr*)address, address.size) == 0;
            if(!success){
                log_error("Unable to bind socket fd. Aborting.\n");
                close_socket(socket);

            }
        }
        else{
            log_error("Unable to bind socket: Invalid address.\n");
        }
        return success;
    }

    String get_address_string(Socket_Address* address, char[] buffer){
        assert(buffer.length >= INET6_ADDRSTRLEN);

        assert(address.sin_family == AF_INET);
        auto raw = inet_ntop(address.sin_family, &address.ipv4.sin_addr, buffer.ptr, cast(uint)buffer.length);
        auto result = raw[0 .. strlen(raw)];
        return result;
    }

    /+
    private bool socket_connect(Socket* sock){
        assert(sock.status == Socket_Status.Opened || sock.status == Socket_Status.Connecting);

        // Async use of connect adapted from here:
        // https://rigtorp.se/sockets/
        bool failed = false;
        int e = connect(sock.fd, cast(sockaddr*)&sock.address, sock.address.sizeof);
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
    }+/

    void sockets_update(Socket[] sockets, Allocator* allocator){
        auto scratch = allocator.scratch;
        push_frame(scratch);
        scope(exit) pop_frame(scratch);

        // TODO: Consider using epoll? It sounds as though poll tends to take longer than
        // nescissary.
        auto poll_fds     = alloc_array!pollfd(scratch, sockets.length);
        auto poll_sources = alloc_array!(Socket*)(scratch, sockets.length);
        uint poll_fds_count;

        foreach(ref socket; sockets){
            if(socket.status == Socket_Status.Opened
            || socket.status == Socket_Status.Connected){
                auto index = poll_fds_count++;
                auto entry = &poll_fds[index];
                entry.fd = socket.fd;
                entry.events = POLLIN|POLLOUT;
                poll_sources[index] = &socket;
            }
            else if(socket.status == Socket_Status.Connecting){
                assert(0);
                //socket_connect(&socket);
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

    void[] socket_read(Socket *sock, void* buffer, uint buffer_length, Socket_Address* address){
        // TODO: More robust reading
        void[] result;
        if(sock.status != Socket_Status.Closed){
            assert(sock.events & Socket_Event_Readable);

            socklen_t address_size = sockaddr_in.sizeof;
            auto bytes_read = recvfrom(sock.fd, buffer, buffer_length, 0, cast(sockaddr*)address, address ? &address_size : null);
            if(bytes_read > 0){
                if(address){
                    address.size = sockaddr_in.sizeof; // TODO: Or should we remove this field entirely?
                }
                result = buffer[0 .. bytes_read];
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

    void socket_write(Socket *sock, const(void)* buffer, size_t buffer_length, Socket_Address* address){
        // TODO: More robust writing
        auto bytes_written = sendto(sock.fd, buffer, cast(uint)buffer_length, 0, cast(sockaddr*)address, sockaddr_in.sizeof);
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
