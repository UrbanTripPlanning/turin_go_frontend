import axios from 'axios';
import config from './config';

export const searchRoad = async (params) => {
  try {
    const response = await axios.get(`${config.baseURL}/road`, { params });
    return response.data;
  } catch (error) {
    console.error('search road failed', error);
    throw error;
  }
}; 