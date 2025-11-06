FROM node:18-alpine

WORKDIR /app

# Copiar package files
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código fonte
COPY . .

# Expor porta
EXPOSE 3000

# Debug: mostrar estrutura de arquivos
RUN ls -la

# Verificar se há script de start
RUN cat package.json

# Comando para iniciar
CMD ["npm", "start"]
