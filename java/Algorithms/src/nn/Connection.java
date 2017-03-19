package nn;

import java.util.Random;

public class Connection {
	double weight = 0;
	double prevDeltaWeight = 0; // for momentum
	double deltaWeight = 0;

	final Neuron fromNeuron;
	final Neuron toNeuron;
	static int counter = 0;
	static final Random rand = new Random();
	final public int id; // auto increment, starts at 0

	public Connection(Neuron fromN, Neuron toN) {
		fromNeuron = fromN;
		toNeuron = toN;
		// Set random weight
		weight = (rand.nextDouble() * 2 - 1);
		id = counter;
		counter++;
	}

	public double getWeight() {
		return weight;
	}

	public void setWeight(double w) {
		weight = w;
	}

	public void setDeltaWeight(double w) {
		prevDeltaWeight = deltaWeight;
		deltaWeight = w;
	}

	public double getPrevDeltaWeight() {
		return prevDeltaWeight;
	}

	public Neuron getFromNeuron() {
		return fromNeuron;
	}

	public Neuron getToNeuron() {
		return toNeuron;
	}
}