FROM node:18-alpine

WORKDIR /app

# Copiar package files
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código fonte
COPY . .

# Expor porta (ajuste conforme necessário)
EXPOSE 3000

# Comando para iniciar a aplicação
CMD ["npm", "start"]
