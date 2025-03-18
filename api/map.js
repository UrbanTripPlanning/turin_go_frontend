import axios from 'axios';
import config from './config';

export const getMapInfo = async () => {
  try {
    const response = await axios.get(`${config.baseURL}/map/info`);
    return response.data;
  } catch (error) {
    console.error('get map info failed', error);
    throw error;
  }
}; 

export const getTraffic = async () => {
  try {
    const response = await axios.get(`${config.baseURL}/map/traffic`);
    return response.data;
  } catch (error) {
    console.error('get traffic info failed', error);
    throw error;
  }
};

export const getWeather = async () => {
  try {
    const response = await axios.get(`${config.baseURL}/map/weather`);
    return response.data;
  } catch (error) {
    console.error('get weather data failed', error);
    throw error;
  }
};
