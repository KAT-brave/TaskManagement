import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:8080',
});

export const fetchCards = () => api.get('/api/cards').then(res => res.data);
