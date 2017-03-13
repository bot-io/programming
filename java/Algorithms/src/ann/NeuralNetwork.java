package ann;

import java.util.ArrayList;

import logger.Logger;

public class NeuralNetwork {

	private Logger logger = new Logger();
	double learningRate = 0.1;
	ArrayList<OutputNeuron> neurons = new ArrayList<>();

	public NeuralNetwork() {
		// Input neurons
		OutputNeuron n0 = new OutputNeuron(1, "input1");
		OutputNeuron n1 = new OutputNeuron(1, "input2");

		// Middle layer neurons
		OutputNeuron n2 = new OutputNeuron(1, "hidden1");
		n2.inputs.put(n0, 0.8);
		n2.inputs.put(n1, 0.2);
		OutputNeuron n3 = new OutputNeuron(1, "hidden2");
		n3.inputs.put(n0, 0.4);
		n3.inputs.put(n1, 0.9);
		OutputNeuron n4 = new OutputNeuron(1, "hidden3");
		n4.inputs.put(n0, 0.3);
		n4.inputs.put(n1, 0.5);

		// Output neuron
		OutputNeuron n5 = new OutputNeuron(1, "output");
		n5.inputs.put(n2, 0.3);
		n5.inputs.put(n3, 0.5);
		n5.inputs.put(n4, 0.9);

		// Add all neurons to the network
		neurons.add(n0);
		neurons.add(n1);
		neurons.add(n2);
		neurons.add(n3);
		neurons.add(n4);
		neurons.add(n5);

		for (int i = 0; i < 100; i++) {
			pulse(i);
		}

	}

	public void pulse(int count) {
		logger.log("Pulse: "+count);
		activate();
		print();
		adjustWeights();
		print();
	}

	public void activate() {
		for (int i = 2; i < neurons.size(); i++) {
			OutputNeuron n = neurons.get(i);
			n.activate();
		}
	}

	public void adjustWeights() {
		OutputNeuron n = neurons.get(neurons.size() - 1);
		n.calculateCorrectionDelta(0);
		n.adjustWeights();
	}

	public void print() {
		logger.log("\n");
		for (int i = 0; i < neurons.size(); i++) {
			OutputNeuron n = neurons.get(i);
			logger.log(n.toString());
		}
	}
}
