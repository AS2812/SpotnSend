import { Server } from 'socket.io';
import env from '../config/env.js';

export function createSocketServer(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: env.server.corsOrigins.length ? env.server.corsOrigins : '*'
    }
  });

  io.on('connection', (socket) => {
    socket.on('join:user', (userId) => {
      if (userId) socket.join(`user:${userId}`);
    });
    socket.on('join:city', (city) => {
      if (city) socket.join(`city:${city.toLowerCase()}`);
    });
    socket.on('disconnect', () => {
      // placeholder for cleanup
    });
  });

  return io;
}

export function emitUserNotification(io, userId, payload) {
  io.to(`user:${userId}`).emit('notification', payload);
}

export function emitReportUpdate(io, city, payload) {
  if (city) {
    io.to(`city:${city.toLowerCase()}`).emit('report:update', payload);
  }
}
