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

	public double target;

	public Map<Neuron, Double> weights = new HashMap<>();

	public double activate() {
		// Put the input sum through the decided activation function
		output = Util.sigmoid(getInputsSum());

		return output;
	}

	private double getInputsSum() {
		double result = 0;
		// Sum all incoming neurons outputs multiplied by the
		// connection weight
		for (Neuron n : weights.keySet()) {
			result += weights.get(n) * n.output;
		}

		return result;
	}

	public double getCorrectionDelta(double target) {
		double error = output - target;
		double correctionDelta = Util.sigmoidDerivative(getInputsSum()) * error;
		return correctionDelta;
	}

	public void adjustWeights(double target) {
		getCorrectionDelta(target);

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
