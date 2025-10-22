import { PrismaClient } from "./generated/prisma"

const globalForPrisma = global as unknown {
  prisma: PrismaClient
}

const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

export default prisma;
