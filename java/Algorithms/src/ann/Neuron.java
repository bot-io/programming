package ann;

import java.util.HashMap;
import java.util.Map;

import util.Util;

public class Neuron {

	public Neuron(double output) {
		this.output = output;
	}

	public double weight;
	public double bias;
	public double output;

	public Map<Neuron, Double> weights = new HashMap<>();

	double activate() {
		output = 0;
		for (Neuron n : weights.keySet()) {
			output += weights.get(n) * n.output;
		}
		output = Util.sigmoid(output);

		return output;
	}

	@Override
	public String toString() {
		String result = "";

		if (!weights.isEmpty()) {
			result += "Weights: ";
			for (Neuron n : weights.keySet()) {
				result += weights.get(n) + ", ";
			}
		}

		result += "output: " + output;

		return result;
	}

}
