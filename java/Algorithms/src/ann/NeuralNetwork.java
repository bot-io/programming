package ann;

import java.util.ArrayList;

public class NeuralNetwork {

	ArrayList<Neuron> neurons = new ArrayList<>();

	public NeuralNetwork() {
		Neuron n0 = new Neuron(1);
		Neuron n1 = new Neuron(1);

		Neuron n2 = new Neuron(1);
		n2.weights.put(n0, 0.8);
		n2.weights.put(n1, 0.2);
		Neuron n3 = new Neuron(1);
		n3.weights.put(n0, 0.4);
		n3.weights.put(n1, 0.9);
		Neuron n4 = new Neuron(1);
		n4.weights.put(n0, 0.3);
		n4.weights.put(n1, 0.5);

		Neuron n5 = new Neuron(1);
		n5.weights.put(n2, 0.3);
		n5.weights.put(n3, 0.5);
		n5.weights.put(n4, 0.9);

		neurons.add(n0);
		neurons.add(n1);
		neurons.add(n2);
		neurons.add(n3);
		neurons.add(n4);
		neurons.add(n5);

		n2.activate();
		n3.activate();
		n4.activate();
		n5.activate();

		print();
	}

	public void print() {
		for (int i = 0; i < neurons.size(); i++) {
			Neuron n = neurons.get(i);
			System.out.println("n" + i + ": " + n.toString());
		}
	}
}
