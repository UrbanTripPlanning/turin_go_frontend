import axios from 'axios';
import config from './config';

export const getUserData = async () => {
  try {
    const response = await axios.get(`${config.baseURL}/user`);
    return response.data;
  } catch (error) {
    console.error('get user data failed', error);
    throw error;
  }
}; 