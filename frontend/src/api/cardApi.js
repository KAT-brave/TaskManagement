import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:8080',
});

export const fetchCards = () => api.get('/api/cards').then(res => res.data);

export const createCard = (data) => api.post('/api/cards', data).then(res => res.data);

export const updateCard = (id, data) => api.put(`/api/cards/${id}`, data).then(res => res.data);

export const deleteCard = (id) => api.delete(`/api/cards/${id}`);
